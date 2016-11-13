require 'textile/parser'

module Textile
  def self.parse(text)
    TextileParser.parse(text.dup)
  end
end
