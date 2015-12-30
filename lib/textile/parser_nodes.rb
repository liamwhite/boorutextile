# Parser nodes for the Textile parser.
module Textile
  def self.html_escape(term)
    term.gsub(/[\n\r&<>]/, "\n" => '<br/>', "\r" => '', '&' => '&amp;', '<' => '&lt;', '>' => '&gt;')
  end

  # Raw text to be output for HTML escaping
  TermNode = Struct.new(:term) do
    def build
      Textile.html_escape(term)
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

  # <a>
  LinkNode = Struct.new(:target, :child) do
    def build
      %{<a href="#{Textile.html_escape(target)}">#{child.build}</a>}
    end
  end

  # <img>
  ImageNode = Struct.new(:target) do
    def for_link; self end

    def build
      %{<img src="#{Textile.html_escape(target)}"/>}
    end
  end

  # Pseudo-node used for AST manipulation
  QuoteNode = Struct.new(:child) do
    def for_link; child end

    def build
      %{"#{child.build}"}
    end
  end

  # <blockquote>
  class BlockquoteNode
    attr_accessor :child, :author

    def initialize(child, author = '')
      @child = child
      @author = author
    end

    def build
      %{<blockquote author="#{Textile.html_escape(author)}">#{child.build}</blockquote>}
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
