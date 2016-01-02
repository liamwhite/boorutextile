require 'textile/lexer'
require 'textile/parser'
require 'textile/renester'

module Textile
  def self.parse(text, &block)
    tokens = Renester.renest(Lexer.new(text).lex)
    Parser.new(tokens, block).parsed
  end
end
