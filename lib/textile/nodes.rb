# frozen_string_literal: true
require 'cgi'

class MultiNode
  def initialize(nodes)
    @nodes = nodes || []
  end

  def build
    @nodes.map(&:build).join('')
  end
end

class TextNode
  def initialize(text)
    @text = text
  end

  # Hook for booru monkeypatch
  def build
    CGI.escapeHTML(@text).gsub("\n", '<br>')
  end
end

class RawTextNode
  def initialize(text)
    @text = text
  end

  def build
    CGI.escapeHTML(@text).gsub("\n", '<br>')
  end
end

class HTMLNode
  def initialize(tag_name, inner, attributes = {})
    @tag_name = tag_name
    @inner = inner
    @attributes = attributes || {}
  end

  def build
    output = []
    output << '<'
    output << @tag_name
    @attributes.each do |name, value|
      output << ' '
      output << name
      output << '="'
      output << CGI.escapeHTML(value)
      output << '"'
    end
    output << '>'
    output << @inner.build
    output << '</'
    output << @tag_name
    output << '>'
    output.join('')
  end
end

class ImageNode < HTMLNode
  def initialize(src)
    @src = src
  end

  def build
    output = []
    output << '<img src="'
    output << transform_src
    output << '"/>'
    output.join('')
  end

  # Hook for booru monkeypatch
  def transform_src
    CGI.escapeHTML(@src)
  end
end
