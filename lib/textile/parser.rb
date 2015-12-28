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
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{TRIVIAL_OPERATORS[i]}
          if accept(:#{TRIVIAL_OPERATORS[i]})
            op = @last.string
            prox = #{TRIVIAL_OPERATORS[i+1]}
            if accept(:#{TRIVIAL_OPERATORS[i]})
              OperatorNode.new(:#{TRIVIAL_OPERATORS[i]}, prox)
            else
              BinaryTextNode.new(TermNode.new(op), prox)
            end
          else
            #{TRIVIAL_OPERATORS[i+1]}
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
        
        while accept(:word) || accept(:space)
          buffer << @last.string
        end
        
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
      return false unless @current and @current.type == type
      advance || true
    end
    
    def expect(type)
      accept(type) or fail "Expected #{type.inspect}, got #{@current.inspect}"
    end
  end
end
