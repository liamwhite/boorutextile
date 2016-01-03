module Textile
  class Lexer
    LexerToken = Struct.new(:type, :string, :nesting)

    # Ruby \s does not match extra unicode space characters.
    RX_SPACE_CHARS = ' \t\u00a0\u1680\u180E\u2000-\u200A\u202F\u205F\u3000'

    # Token list for lexer.
    # The hash defines what matching operand turns this into an operator.
    RX_TOKENS = [
      [:newline, /\n/],
      [:space, /[#{RX_SPACE_CHARS}]/],

      # Oh shit.
      [:url, %r{
               (?:http:\/\/|https:\/\/|\/\/|\/|\#)                     # protocol
               (?:[^%#{RX_SPACE_CHARS}"!\n\r]|%[0-9a-fA-F]{2})+        # path
               [^#{RX_SPACE_CHARS}`~!@$^&"\n\r\*_+\-=\[\]\\|;:,.'?\#)] # invalid
             }x],

      # Context-sensitive operators that require a matching pair to
      # be considered an operator
      [:asterisk,   /\*/, end: :asterisk,   op: :bold],
      [:caret,      /\^/, end: :caret,      op: :sup],
      [:plus,       /\+/, end: :plus,       op: :ins],
      [:minus,      /-/,  end: :minus,      op: :del],
      [:underscore, /_/,  end: :underscore, op: :em],
      [:at,         /@/,  end: :at,         op: :code],
      [:tilde,      /~/,  end: :tilde,      op: :sub],
      [:dblequal,   /==/, end: :dblequal,   op: :raw_1],

      # Link operators
      [:exclamation, /!/],
      [:colon,       /:/],
      [:quot,        /"/, end: :quot, op: :quote],

      # This is a link operator too, albeit a special one. Image URLs are
      # allowed to contain a closing parenthesis, while quote URLs are not.
      [:rparen, /\)/],

      # Block operators
      [:spoiler_start, /\[spoiler\]/,      end: :spoiler_end, op: :spoiler],
      [:spoiler_end,   /\[\/spoiler\]/],
      [:pre_start,     /\[pre\]/,          end: :pre_end, op: :pre],
      [:pre_end,       /\[\/pre\]/],
      [:bq_start,      /\[bq\]/,           end: :bq_end, op: :block],
      [:bq_author,     /\[bq="([^"]*)"\]/, end: :bq_end, op: :block_author],
      [:bq_end,        /\[\/bq\]/],
      [:raw_start,     /\[==/,             end: :raw_end, op: :raw_2],
      [:raw_end,       /==\]/],
      [:lbracket,      /\[/                end: :rbracket, op: :bracket],
      [:rbracket,      /\]/],

      # Treat 2+ of the operators as a word instead:
      [:ignore, /(\*{2,}|\^{2,}|\+{2,}|-{2,}|_{2,}|@{2,}|~{2,}|\[{2,})/],
    ].freeze

    # By first matching against a union of all possible tokens, we can find
    # the first match possible *and* match the longest token possible.
    RX_MATCHABLE = Regexp.union(RX_TOKENS.map{|k| k[1]}).freeze

    def initialize(input)
      @input = input.dup
      @tokens = []
    end

    # Consume @input and convert it into tokens.
    def lex
      until @input.empty?
        md = RX_MATCHABLE.match(@input)

        if md
          # Slice off the portion before the match
          pre = @input.slice!(0, md.pre_match.size)
          @tokens << LexerToken.new(:word, pre) unless pre.empty?

          # Now add the main match group
          @tokens << match_token
        else
          # Nothing to do here.
          @tokens << LexerToken.new(:word, @input)
          @input = ''
        end
      end

      @tokens << LexerToken.new(:eof, '$')
    end

    private

    def match_token
      best_match = nil

      RX_TOKENS.each do |type, regex, nest|
        result = regex.match(@input)

        # Make sure that the match starts at the first character.
        next unless result && result.pre_match.empty?
        string = result.to_s

        # No match? Add it. Better match? Add it.
        next unless !best_match || best_match[1].size < string.size
        best_match = [type, string, nest]
      end

      type, string, nest = best_match
      @input.slice!(0, string.size)
      LexerToken.new(type, string, nest)
    end
  end
end
