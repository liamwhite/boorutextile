require 'textile/parser'
require 'textile/lexer'

module Textile
  def self.parse(text)
    Parser.new(Lexer.lex(text)).parsed
  end
end
