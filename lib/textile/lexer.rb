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

      # Context-sensitive operators that require a matching pair to
      # be considered an operator
      :asterisk   => /\*/,
      :caret      => /\^/,
      :plus       => /\+/,
      :underscore => /_/,
      :at         => /@/,
      :tilde      => /~/,

      # Link operators
      :exclamation => /!/,
      :quote       => /"/,
      :colon       => /:/,

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

    RX_TOKEN_LIST = RX_TOKENS.keys.zip(RX_TOKENS.values).freeze
    RX_MATCHABLE = /(#{RX_TOKENS.values.map(&:to_s).join('|')})/.freeze

    # Convert input to token stream
    def self.lex(input)
      tokens = []
      input.split(RX_MATCHABLE).each do |token|
        tokens << match_token(token)
      end

      tokens << LexerToken.new(:eof, '$')
      tokens.compact
    end

    def self.match_token(input)
      return if input.empty?

      best_match = nil
      RX_TOKEN_LIST.each do |rule|
        result = rule[1].match(input)
        best_match = [rule[0], input] if result
      end

      LexerToken.new(*(best_match || [:word, input]))
    end
  end
end
