# Parser nodes for the Textile parser
module Textile
  def self.html_escape(term)
    term.gsub(/[\n\r&<>]/, "\n" => '<br/>', "\r" => '', '&' => '&amp;', '<' => '&lt;', '>' => '&gt;')
  end

  RX_TITLE = /\A([^\(]+)\(([^\)]*)\)\z/.freeze

  # Extracts the title attribute from an image or link.
  #
  #   !foo(bar)!      #=> <img src="foo" title="bar"/>
  #   "foo(bar)":/foo #=> <a href="/foo" title="bar">foo</a>
  #
  def self.extract_title(string)
    md = RX_TITLE.match(string)
    return [md[1], md[2]] if md
    [string, nil]
  end


  # Raw text to be output for HTML escaping
  TermNode = Struct.new(:term) do
    def build
      Textile.html_escape(term)
    end
  end

  # Unescaped text. BE CAREFUL.
  TextNode = Struct.new(:text) do
    def build
      text
    end
  end

  # Operators in the form of <op>[...]</op>
  OperatorNode = Struct.new(:operator, :child) do
    OPERATOR_TO_HTML = {
      :asterisk   => 'b',
      :caret      => 'sup',
      :plus       => 'ins',
      :minus      => 'del',
      :underscore => 'em',
      :at         => 'code',
      :tilde      => 'sub',
      :pre        => 'pre',
    }.freeze

    def build
      "<#{html}>#{child.build}</#{html}>"
    end

    def html
      OPERATOR_TO_HTML.fetch(operator, 'span')
    end
  end

  # <span class="spoiler">
  SpoilerNode = Struct.new(:child) do
    def build
      %{<span class="spoiler">#{child.build}</span>}
    end
  end

  # <img>
  ImageNode = Struct.new(:target) do
    def build_link(target)
      LinkNode.new(target, self)
    end

    def build
      @src, @title = Textile.extract_title(target) if !@src
      %{<img src="#{Textile.html_escape(@src)}" title="#{@title}"/>}
    end
  end

  # Pseudo-node used for AST manipulation
  QuoteNode = Struct.new(:child) do
    def build_link(target)
      text, title = Textile.extract_title(child.build)
      LinkNode.new(target, TextNode.new(text), title)
    end

    def build
      %{"#{child.build}"}
    end
  end

  # <a>
  class LinkNode
    attr_accessor :target, :child, :title

    def initialize(target, child, title = nil)
      @target = target
      @child = child
      @title = title
    end

    def build
      %{<a href="#{Textile.html_escape(target)}" title="#{@title}">#{child.build}</a>}
    end
  end

  # <blockquote>
  class BlockquoteNode
    RX_QUOTE_CITE = /\[bq="([^"]*)"\]/.freeze

    attr_accessor :child, :author

    def initialize(child, author)
      @child = child
      @author = extract_author(author) || ''
    end

    def build
      %{<blockquote author="#{author}">#{child.build}</blockquote>}
    end

    def extract_author(author)
      return if author.empty?
      Textile.html_escape(RX_QUOTE_CITE.match(author)[1]
    end
  end

  # AST node with multiple children, built and joined in order
  class PolyTextNode
    attr_accessor :children

    def initialize(*args)
      @children = args
    end

    def build
      [*children].map(&:build).join('')
    end
  end
end
