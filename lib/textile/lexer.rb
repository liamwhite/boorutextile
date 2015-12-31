module Textile
  class Lexer
    LexerToken = Struct.new(:type, :string)

    # Ruby \s does not match extra unicode space characters.
    RX_SPACE_CHARS = ' \t\u00a0\u1680\u180E\u2000-\u200A\u202F\u205F\u3000'

    # Token list for lexer.
    RX_TOKENS = {
      # Paragraph mark
      :paragraph => /\n\n/,
      :space => /[#{RX_SPACE_CHARS}]/,

      # Oh shit.
      :url => %r{
                (?:http:\/\/|https:\/\/|\/\/|\/|\#)              # protocol
                (?:[^%#{RX_SPACE_CHARS}"!\n\r]|%[0-9a-fA-F]{2})+ # path
                [^#{RX_SPACE_CHARS}`~!@$^&"\*_+\-=\[\]\\|;:,.'?\#)] # invalid
              }x,

      # Context-sensitive operators that require a matching pair to
      # be considered an operator
      :asterisk   => /\*/,
      :caret      => /\^/,
      :plus       => /\+/,
      :minus      => /-/,
      :underscore => /_/,
      :at         => /@/,
      :tilde      => /~/,
      :dblequal   => /==/,

      # Link operators
      :exclamation => /!/,
      :quote       => /"/,
      :colon       => /:/,

      # This is a link operator too, albeit a special one. Image URLs are
      # allowed to contain a closing parenthesis, while quote URLs are not.
      :rparen      => /\)/,

      # Block operators
      :spoiler_start => /\[spoiler\]/,
      :spoiler_end   => /\[\/spoiler\]/,
      :pre_start     => /\[pre\]/,
      :pre_end       => /\[\/pre\]/,
      :bq_start      => /\[bq\]/,
      :bq_author     => /\[bq="([^"]*)"\]/,
      :bq_end        => /\[\/bq\]/,
      :raw_start     => /\[==/,
      :raw_end       => /==\]/,
    }.freeze

    # By first matching against a union of all possible tokens, we can find
    # the first match possible *and* match the longest token possible.
    RX_MATCHABLE = Regexp.union(RX_TOKENS.values).freeze

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

      RX_TOKENS.each do |type, regex|
        result = regex.match(@input)

        # Make sure that the match starts at the first character.
        if result && result.pre_match.empty?
          string = result.to_s

          # No match? Add it. Better match? Add it.
          if !best_match || best_match[1].size < string.size
            best_match = [type, string]
          end
        end
      end

      type, string = best_match
      @input.slice!(0, string.size)
      LexerToken.new(type, string)
    end
  end
end
