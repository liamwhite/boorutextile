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

    TRIVIAL_OPERATORS = [:asterisk, :caret, :plus, :underscore, :at, :tilde, :pre].freeze

    # Ignores the last one so that we can define it manually
    6.times do |i|
      this_sym = TRIVIAL_OPERATORS[i]
      next_sym = TRIVIAL_OPERATORS[i+1]

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{this_sym}
          if accept(:#{this_sym})
            op = @last.string
            prox = #{next_sym}
            if accept(:#{this_sym})
              OperatorNode.new(:#{this_sym}, prox)
            else
              BinaryTextNode.new(TermNode.new(op), prox)
            end
          else
            #{next_sym}
          end
        end
      RUBY
    end

    def pre
      if accept(:pre_start)
        node = OperatorNode.new(:pre, terminal)
        expect(:pre_end)
        node
      else
        terminal
      end
    end

    def terminal
      if accept(:word) || accept(:space)
        buffer = @last.string
        buffer << @last.string while accept(:word) || accept(:space)
        TermNode.new(buffer)
      else
        asterisk
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

    def expect(type)
      accept(type) || fail "Expected #{type.inspect}, got #{@current.inspect}"
    end
  end
end
