require 'textile/parser'
require 'textile/lexer'

module Textile
  def self.parse(text, &block)
    tokens = Lexer.new(text).lex
    Parser.new(tokens, block).parsed
  end
end
