require 'textile/parser_nodes'

module Textile
  class Parser
    attr_reader :parsed

    # The parser accepts a proc to perform substitutions on any HTML-escaped terms.
    def initialize(tokens, custom = nil)
      @tokens = tokens.dup
      @custom = custom
      @parsed = parse
    end

    def parse
      advance
      ast = []
      ast << colon.build until accept(:eof)
      ast.join('')
    end

    # link-rule:
    #   | image ':' url
    #   | quote ':' url
    #   : quote
    def colon
      prox = quote
      if accept(:colon)
        if prox.is_a?(QuoteNode) || prox.is_a?(ImageNode)
          return prox.build_link(@last.string) if accept(:url)
          PolyTextNode.new(prox, term_node(':'))
        else
          PolyTextNode.new(prox, term_node(':'))
        end
      else
        prox
      end
    end

    # quote-rule:
    #   | '"' image '"'
    #   : image
    def quote
      if accept(:quote)
        backtrack(:quote, :image) do |n|
          QuoteNode.new(n)
        end
      else
        image
      end
    end

    # image-rule:
    #   | '!' url '!'
    #   : terminal
    def image
      if accept(:exclamation)
        if accept(:url)
          url = @last.string

          # NESTING OVER 9000
          if accept(:rparen)
            return ImageNode.new("#{url})") if accept(:exclamation)
            return PolyTextNode.new(term_node("!#{url})"), terminal)
          elsif accept(:exclamation)
            ImageNode.new(url)
          else
            PolyTextNode.new(term_node("!#{url}"), terminal)
          end          
        else
          PolyTextNode.new(term_node('!'), terminal)
        end
      else
        terminal
      end
    end

    def terminal
      if accept(:word) || accept(:space)
        buffer = @last.string
        buffer << @last.string while accept(:word) || accept(:space)
        term_node(buffer)
      elsif accept(:asterisk) || accept(:caret) || accept(:plus) ||
            accept(:underscore) || accept(:minus) || accept(:at) ||
            accept(:tilde)
        type = @last.type
        backtrack(type, :colon) do |n|
          OperatorNode.new(type, n)
        end
      elsif accept(:pre_start)
        backtrack(:pre_end, :colon) do |n|
          OperatorNode.new(:pre, n)
        end
      elsif accept(:spoiler_start)
        backtrack(:spoiler_end, :colon) do |n|
          SpoilerNode.new(n)
        end
      elsif accept(:bq_start)
        backtrack(:bq_end, :colon) do |n|
          BlockquoteNode.new(n)
        end
      elsif accept(:bq_author)
        cite = @last.string
        backtrack(:bq_end, :colon) do |n|
          BlockquoteNode.new(n, cite)
        end
      elsif accept(:raw_start)
        term_node(concat_until(:raw_end) || '[==', true)
      elsif accept(:dblequal)
        term_node(concat_until(:dblequal) || '==', true)
      elsif peek?(:eof)
        term_node('')
      else
        # No more parser rules match this
        advance
        term_node(@last.string)
      end
    end

    def advance
      @last = @current
      @current = @tokens.shift
    end

    def accept(type)
      return false unless peek?(type)
      advance || true
    end

    def peek?(type)
      @current && @current.type == type
    end

    # Textile cannot use predictive parsing, because markup isn't context-free.
    # Finds if this operator has a matching pair (+next_token+) in @tokens, and
    # yields the current parse tree if it does; otherwise, returns the operator
    # string as a term node including the rest of the parse tree (+next_node+).
    def backtrack(next_token, next_node)
      op = @last.string

      # for 2 adjacent ops, bail out
      return term_node("#{op}#{@last.string}") if accept(next_token)

      current = PolyTextNode.new
      loop do
        prox = send(next_node)
        current.children << prox
        if accept(next_token)
          return yield current
        elsif peek?(:eof)
          return PolyTextNode.new(term_node(op), current)
        end
      end
    end

    # Helper for implementing == and [==
    # Checks to see if the matching token exists, and then eats strings
    # until the token is found
    def concat_until(token)
      return unless @tokens.index{|op| op.type == token }
      buffer = ""

      until accept(token)
        advance
        buffer << @last.string
      end

      buffer
    end

    def term_node(string, raw = false)
      if raw
        TermNode.new(string)
      else
        TermNode.new(string, @custom)
      end
    end
  end
end
