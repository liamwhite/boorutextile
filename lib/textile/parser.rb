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

    TRIVIAL_OPERATORS = [:asterisk, :caret, :plus, :underscore, :at, :tilde, :terminal].freeze

    # Ignores the last one so that we can define it manually
    6.times do |i|
      this_sym = TRIVIAL_OPERATORS[i]
      next_sym = TRIVIAL_OPERATORS[i+1]

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{this_sym}
          if accept(:#{this_sym})
            backtrack(:#{next_sym}, :#{next_sym}) do |n|
              OperatorNode.new(:#{this_sym}, n)
            end
          else
            #{next_sym}
          end
        end
      RUBY
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
      else
        # No more parser rules match this
        TermNode.new(@current.string)
      end
    end

    def advance
      @last = @current
      @current = @tokens.shift
    end

    def accept(type)
      return false unless @current && @current.type == type
      advance || true
    end

    def backtrack(next_token, next_node)
      op = @last.string
      prox = send(next_node)
      if accept(next_token)
        yield prox
      else
        BinaryTextNode.new(TermNode.new(op), prox)
      end
    end
  end
end
