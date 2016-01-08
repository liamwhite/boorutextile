module Textile
  class Lexer
    LexerToken = Struct.new(:type, :string, :nesting)

    # Ruby \s does not match extra unicode space characters.
    RX_SPACE_CHARS = ' \t\u00a0\u1680\u180E\u2000-\u200A\u202F\u205F\u3000'

    RX_URL = %r{
               (?:http:\/\/|https:\/\/|\/\/|\/|\#)                     # protocol
               (?:[^%#{RX_SPACE_CHARS}"!\n\r]|%[0-9a-fA-F]{2})+        # path
               [^#{RX_SPACE_CHARS}`~!@$^&"\n\r\*_+\-=\[\]\\|;:,.'?\#)] # invalid
             }x

    # Tokens that do not require regex. NB put longer tokens first
    # [name, starts_with (, nest_options)]
    NON_RX_TOKENS = [
      # Newlines and paragraphs
      [:paragraph, "\n\n"],
      [:paragraph, "\r\n\r\n"],
      [:newline, "\n"],
      [:newline, "\r\n"],

      # Block operators
      [:spoiler_start, "[spoiler]", end: :spoiler_end, op: :spoiler],
      [:spoiler_end,   "[/spoiler]"],
      [:pre_start,     "[pre]",     end: :pre_end, op: :pre],
      [:pre_end,       "[/pre]"],
      [:bq_start,      "[bq]",      end: :bq_end, op: :block],
      [:bq_end,        "[/bq]"],
      [:raw_start,     "[==",       end: :raw_end, op: :raw_2],
      [:raw_end,       "==]"],

      # Context-sensitive operators that require a matching pair to
      # be considered an operator
      [:asterisk,   "*", end: :asterisk,   op: :bold, break: :paragraph],
      [:caret,      "^", end: :caret,      op: :sup,  break: :paragraph],
      [:plus,       "+", end: :plus,       op: :ins,  break: :paragraph],
      [:minus,      "-",  end: :minus,      op: :del,  break: :paragraph],
      [:underscore, "_",  end: :underscore, op: :em,   break: :paragraph],
      [:tilde,      "~",  end: :tilde,      op: :sub,  break: :paragraph],
      [:at,         "@",  end: :at,         op: :code, break: :paragraph],
      [:dblequal,   "==", end: :dblequal,   op: :raw_1, break: :paragraph],

      # Link operators
      [:exclamation, "!"],
      [:colon,       ":"],
      [:quot,        '"', end: :quot, op: :quote],

      # This is a link operator too, albeit a special one. Image URLs are
      # allowed to contain a closing parenthesis, while quote URLs are not.
      [:rparen, ")"],
    ].freeze

    # Tokens that require regex.
    # [name, starts_with, regex (, nest_options)]
    RX_TOKENS = [
      [:bq_author, '[bq="', /\[bq="([^"]*)"\]/, end: :bq_end, op: :block_author],
      [:url, 'http:', RX_URL],
      [:url, 'https:', RX_URL],
      [:url, '/', RX_URL], # also matches //
      [:url, '#', RX_URL],
    ].freeze
    
    def initialize(input)
      @input = input.dup
      @tokens = []
    end
    
    def lex
      until @input.empty?
        if tok = match
          if @word
            @tokens << @word
            @word = nil
          end

          @tokens << tok
        else
          @word ||= LexerToken.new(:word, "")
          @word.string << @input[0]
          @input = @input[1 .. -1]
        end
      end
      
      @tokens << @word if @word
      @tokens << LexerToken.new(:eof, '$')
    end
    
    def match
      # First try RX_TOKENS
      RX_TOKENS.each do |name, start, regex, nesting|
        if @input.start_with?(start)
          # Does it match?
          if (md = regex.match(@input))
            string = md.to_s
            @input = @input[string.size .. -1]
            return LexerToken.new(name, string, nesting)
          end
        end
      end
      
      # No luck in RX_TOKENS, go to regular
      NON_RX_TOKENS.each do |name, start, nesting|
        if @input.start_with?(start)
          @input = @input[start.size .. -1]
          return LexerToken.new(name, start, nesting)
        end
      end
      
      # Nothing left.
      nil
    end
  end
end
