require 'textile/parser'
require 'textile/lexer'

module Textile
  def self.parse(text)
    tokens = Lexer.new(text).lex
    Parser.new(tokens).parsed
  end
end
