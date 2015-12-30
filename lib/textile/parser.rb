require 'textile/parser_nodes'

module Textile
  class Parser
    attr_reader :parsed

    # Textile::Parser will consume lexer tokens to produce parsed, HTML-safe output.
    def initialize(tokens)
      @tokens = tokens.dup
      @parsed = parse
    end

    def parse
      advance
      ast = []
      ast << asterisk.build until accept(:eof)
      ast.join('')
    end

    TRIVIAL_OPERATORS = [:asterisk, :caret, :plus, :minus, :underscore, :at, :tilde, :colon].freeze

    # Ignores the last one so that we can define it manually
    7.times do |i|
      this_sym = TRIVIAL_OPERATORS[i]
      next_sym = TRIVIAL_OPERATORS[i+1]

      # bold-rule etc.
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{this_sym}
          if accept(:#{this_sym})
            backtrack(:#{this_sym}, :#{next_sym}) do |n|
              OperatorNode.new(:#{this_sym}, n)
            end
          else
            #{next_sym}
          end
        end
      RUBY
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
          PolyTextNode.new(prox, TermNode.new(':'))
        else
          PolyTextNode.new(prox, TermNode.new(':'))
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
            return PolyTextNode.new(TermNode.new("!#{url})"), terminal)
          elsif accept(:exclamation)
            ImageNode.new(url)
          else
            PolyTextNode.new(TermNode.new("!#{url}"), terminal)
          end          
        else
          PolyTextNode.new(TermNode.new('!'), terminal)
        end
      else
        terminal
      end
    end

    def terminal
      if accept(:word) || accept(:space)
        buffer = @last.string
        buffer << @last.string while accept(:word) || accept(:space)
        TermNode.new(buffer)
      elsif accept(:pre_start)
        backtrack(:pre_end, :asterisk) do |n|
          OperatorNode.new(:pre, n)
        end
      elsif accept(:spoiler_start)
        backtrack(:spoiler_end, :asterisk) do |n|
          SpoilerNode.new(n)
        end
      elsif accept(:bq_start)
        backtrack(:bq_end, :asterisk) do |n|
          BlockquoteNode.new(n)
        end
      elsif accept(:bq_author)
        cite = @last.string
        backtrack(:bq_end, :asterisk) do |n|
          BlockquoteNode.new(n, cite)
        end
      elsif accept(:raw_start)
        TermNode.new(concat_until(:raw_end) || '[==')
      elsif accept(:dblequal)
        TermNode.new(concat_until(:dblequal) || '==')
      elsif peek?(:eof)
        TermNode.new('')
      else
        # No more parser rules match this
        advance
        TermNode.new(@last.string)
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
      current = PolyTextNode.new

      loop do
        prox = send(next_node)
        current.children << prox
        if accept(next_token)
          return yield current
        elsif peek?(:eof)
          return PolyTextNode.new(TermNode.new(op), current)
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
  end
end
