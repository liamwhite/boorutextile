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

    private

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
      return prox unless accept(:colon)

      if prox.is_a?(QuoteNode) || prox.is_a?(ImageNode)
        return prox.build_link(@last.string) if accept(:url)
        return PolyTextNode.new(prox, term_node(':'))
      else
        return PolyTextNode.new(prox, term_node(':'))
      end
    end

    # quote-rule:
    #   | '"' image '"'
    #   : image
    def quote
      return image unless accept(:quote)
      nest(:quote, :image) {|n| QuoteNode.new(n) }
    end

    # image-rule:
    #   | '!' url '!'
    #   : terminal
    def image
      return terminal unless accept(:exclamation)
      return PolyTextNode.new(term_node('!'), terminal) unless accept(:url)

      url = @last.string
      if accept(:rparen)
        return ImageNode.new("#{url})") if accept(:exclamation)
        return PolyTextNode.new(term_node("!#{url})"), terminal)
      elsif accept(:exclamation)
        ImageNode.new(url)
      else
        PolyTextNode.new(term_node("!#{url}"), terminal)
      end          
    end

    def terminal
      if accept(:word)
        buffer = @last.string
        buffer << @last.string while accept(:word)
        term_node(buffer)
      elsif accept(:bold) || accept(:sup) || accept(:ins) || accept(:em) ||
            accept(:del) || accept(:code) || accept(:sub)
        type = @last.type
        nest(type, :colon) do |n|
          OperatorNode.new(type, n)
        end
      elsif accept(:pre)
        nest(:pre, :colon) do |n|
          OperatorNode.new(:pre, n)
        end
      elsif accept(:spoiler)
        nest(:spoiler, :colon) do |n|
          SpoilerNode.new(n)
        end
      elsif accept(:block)
        nest(:block, :colon) do |n|
          BlockquoteNode.new(n)
        end
      elsif accept(:block_author)
        cite = @last.string
        nest(:block_author, :colon) do |n|
          BlockquoteNode.new(n, cite)
        end
      elsif accept(:raw_1) || accept(:raw_2)
        type = @last.type
        term_node(concat_until(type), true)
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

    # Helper for nesting operators.
    def nest(next_token, next_node)
      op = @last.string

      # for 2 adjacent ops, bail out
      return term_node("#{op}#{@last.string}") if accept(next_token)

      current = PolyTextNode.new
      until accept(next_token)
        prox = send(next_node)
        current.children << prox
      end

      yield current
    end

    # Helper for implementing == and [==
    # Eats strings until the token is found
    def concat_until(token)
      buffer = ""

      until accept(token)
        advance
        buffer << @last.string
      end

      buffer
    end

    def term_node(string, raw = false)
      return TermNode.new(string, @custom) unless raw
      return TermNode.new(string)
    end
  end
end
