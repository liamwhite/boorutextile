# Parser nodes for the Textile parser.
module Textile
  # Raw text to be output for HTML escaping
  class TermNode < Struct.new(:term)
    def build
      term.gsub(/[\n\r&<>]/, "\n" => '<br/>', "\r" => '', '&' => '&amp;', '<' => '&lt;', '>' => '&gt;')
    end
  end

  # Operators in the form of <op>[...]</op>
  class OperatorNode < Struct.new(:operator, :child)
    OPERATOR_TO_HTML = {
      :asterisk   => 'b',
      :caret      => 'sup',
      :plus       => 'ins',
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
  class SpoilerNode < Struct.new(:child)
    def build
      %{<span class="spoiler">#{child.build}</span>}
    end
  end

  # <pre>
  class PreNode < Struct.new(:child)
    def build
      %{<pre>#{child.build}</pre>}
    end
  end

  # <img>
  class ImageNode < Struct.new(:target)
    def build
      %{<img src="#{target}"/>} #TODO HTML-escape target
    end
  end

  # <a href="">
  class LinkNode < Struct.new(:target, :child)
    def build
      %{<a href="#{target}">#{child.build}</a>}
    end
  end

  class BlockquoteNode < Struct.new(:child, :author)
    def build
      %{<blockquote author="#{author}">#{child.build}</blockquote>}
    end
  end

  # Pseudo-node used for AST manipulation
  class QuoteNode < Struct.new(:child)
    def build
      %{"#{child.build}"}
    end
  end

  class BinaryTextNode < Struct.new(:left, :right)
    def build
      %{#{left.build}#{right.build}}
    end
  end
end
