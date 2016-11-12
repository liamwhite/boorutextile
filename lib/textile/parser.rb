# frozen_string_literal: true
require 'textile/nodes'

module TextileParser
  extend self

  def parse(text)
    ary = []
    ary << nesting(text) until text.empty?
    MultiNode.new(ary)
  end

  def nesting(text)
    if    text =~ /\A#{SYMS[:raw_bracket]}/
      balanced = balance_markup(text, $&, '[==', '==]').match(SYMS[:raw_bracket])[1]
      RawTextNode.new(balanced)
    elsif text =~ /\A#{SYMS[:bq_author]}/
      balanced = balance_markup(text, $&, BQ_LEFT, '[/bq]').match(SYMS[:bq_author])[2]
      HTMLNode.new(:blockquote, parse(balanced), title: $1)
    elsif text =~ /\A#{SYMS[:bq]}/
      balanced = balance_markup(text, $&, BQ_LEFT, '[/bq]').match(SYMS[:bq])[1]
      HTMLNode.new(:blockquote, parse(balanced))
    elsif text =~ /\A#{SYMS[:spoiler]}/
      balanced = balance_markup(text, $&, '[spoiler]', '[/spoiler]').match(SYMS[:spoiler])[1]
      HTMLNode.new(:span, parse(balanced), class: 'spoiler')
    else
      non_nesting(text)
    end
  end

  def non_nesting(text)
    if    data = match(text, :raw)
      RawTextNode.new(data[1])
    elsif data = match(text, :link_title_bracket) || match(text, :link_title)
      HTMLNode.new(:a, parse(data[1]), title: data[2], href: data[3])
    elsif data = match(text, :link_bracket) || match(text, :link)
      HTMLNode.new(:a, parse(data[1]), href: data[2])
    elsif data = match(text, :image_link_title_bracket) || match(text, :image_link_title)
      HTMLNode.new(:a, ImageNode.new(data[1]), title: data[2], href: data[3])
    elsif data = match(text, :image_link_bracket) || match(text, :image_link)
      HTMLNode.new(:a, ImageNode.new(data[1]), href: data[2])
    elsif data = match(text, :image_title_bracket) || match(text, :image_title)
      HTMLNode.new(:span, ImageNode.new(data[1]), title: data[2])
    elsif data = match(text, :image_bracket) || match(text, :image)
      ImageNode.new(data[1])
    elsif data = match(text, :dblbold_bracket) || match(text, :dblbold)
      HTMLNode.new(:b, parse(data[1]))
    elsif data = match(text, :bold_bracket) || match(text, :bold)
      HTMLNode.new(:strong, parse(data[1]))
    elsif data = match(text, :dblitalic_bracket) || match(text, :dblitalic)
      HTMLNode.new(:i, parse(data[1]))
    elsif data = match(text, :italic_bracket) || match(text, :italic)
      HTMLNode.new(:em, parse(data[1]))
    elsif data = match(text, :code_bracket) || match(text, :code)
      HTMLNode.new(:code, parse(data[1]))
    elsif data = match(text, :ins_bracket) || match(text, :ins)
      HTMLNode.new(:ins, parse(data[1]))
    elsif data = match(text, :sup_bracket) || match(text, :sup)
      HTMLNode.new(:sup, parse(data[1]))
    elsif data = match(text, :del_bracket) || match(text, :del)
      HTMLNode.new(:del, parse(data[1]))
    elsif data = match(text, :sub_bracket) || match(text, :sub)
      HTMLNode.new(:sub, parse(data[1]))
    elsif data = match(text, :cite_bracket) || match(text, :cite)
      HTMLNode.new(:cite, parse(data[1]))
    else
      removed = text.split(ALL_MATCHERS, 2)[0]
      text.slice!(0 ... removed.length)
      TextNode.new(removed)
    end
  end

  private

  # Cuts a match out of text.
  def match(text, sym)
    return unless text =~ /\A#{SYMS[sym]}/

    text.slice!(0 ... $&.length)
    $~
  end

  # Find the longest substring that contains balanced markup,
  # or the whole string if this is impossible.
  # N.B.: always assumes right is a string.
  def balance_markup(text, matched, left, right)
    left_count = matched.scan(left).size
    right_index = -1

    left_count.times do
      if current = matched.index(right, right_index + 1)
        right_index += current + right.size
      end
    end

    text.slice!(0 .. right_index)
    matched[0 .. right_index]
  end

  # Properly nesting operator pairs:
  # [bq][/bq] [bq="author"][/bq]
  # [spoiler][/spoiler]
  # [== ==]

  # Non-nesting operator pairs:
  # == " ! ** * __ _ @ + ^ - ~ ??

  # Ruby \s does not match extra unicode space characters.
  RX_SPACE_CHARS = ' \t\u00a0\u1680\u180E\u2000-\u200A\u202F\u205F\u3000'

  RX_URL = %r{
             (?:http:\/\/|https:\/\/|\/\/|\/|\#)                     # protocol
             (?:[^%#{RX_SPACE_CHARS}"!\n\r]|%[0-9a-fA-F]{2})+        # path
             [^#{RX_SPACE_CHARS}`~!@$^&"\n\r\*_+\-=\[\]\\|;:,.'?\#)] # invalid
           }x

  BQ_LEFT = /\[bq="([^"]*)"\]|\[bq\]/

  SYMS = {
    :raw_bracket => /\[==(.*)==\]/,
    :raw => /==(.*)==/,
    :bq => /\[bq\](.*)\[\/bq\]/,
    :bq_author => /\[bq="([^"]*)"\](.*)\[\/bq\]/,
    :spoiler => /\[spoiler\](.*)\[\/spoiler\]/,
    :link_title_bracket => /\A\["([^"]*)\(([^\)]*)\)":(#{RX_URL})\]/,
    :link_title => /"([^"]*)\(([^\)]*)\)":(#{RX_URL})/,
    :link_bracket => /\["([^"]*)":(#{RX_URL})\]/,
    :link => /"([^"]*)":(#{RX_URL})/,
    :image_link_title_bracket => /\[!(#{RX_URL})\(([^\)]*)\)!:(#{RX_URL})\]/,
    :image_link_title => /!(#{RX_URL})\(([^\)]*)\)!:(#{RX_URL})/,
    :image_link_bracket => /\[!(#{RX_URL})!:(#{RX_URL})\]/,
    :image_link => /!(#{RX_URL})!:(#{RX_URL})/,
    :image_title_bracket => /\[!(#{RX_URL})\(([^\)]*)\)!\]/,
    :image_title => /!(#{RX_URL})\(([^\)]*)\)!/,
    :image_bracket => /\[!(#{RX_URL})!\]/,
    :image => /!(#{RX_URL})!/,
    :dblbold_bracket => /\[\*\*((?:.|\n.|\n(?=\*\*\]))+?)\*\*\]/,
    :dblbold => /\*\*((?:.|\n.|\n(?=\*\*))+?)\*\*/,
    :bold_bracket => /\[\*((?:.|\n.|\n(?=\*\]))+?)\*\]/,
    :bold => /\*((?:.|\n.|\n(?=\*\]))+?)\*/,
    :dblitalic_bracket => /\[__((?:.|\n.|\n(?=__\]))+?)__\]/,
    :dblitalic => /__((?:.|\n.|\n(?=__))+?)__/,
    :italic_bracket => /\A\[_((?:.|\n.|\n(?=_\]))+?)_\]/,
    :italic => /_((?:.|\n.|\n(?=_))+?)_/,
    :code_bracket => /\[@((?:.|\n.|\n(?=@\]))+?)@\]/,
    :code => /@((?:.|\n.|\n(?=@))+?)@/,
    :ins_bracket => /\A\[\+((?:.|\n.|\n(?=\+\]))+?)\+\]/,
    :ins => /\+((?:.|\n.|\n(?=\+))+?)\+/,
    :sup_bracket => /\A\[\^((?:.|\n.|\n(?=\^\]))+?)\^\]/,
    :sup => /\^((?:.|\n.|\n(?=\^))+?)\^/,
    :del_bracket => /\A\[\-((?:.|\n.|\n(?=\-\]))+?)\-\]/,
    :del => /\-((?:.|\n.|\n(?=\-))+?)\-/,
    :sub_bracket => /\A\[\~((?:.|\n.|\n(?=\~\]))+?)\~\]/,
    :sub => /\~((?:.|\n.|\n(?=\~))+?)\~/,
    :cite_bracket => /\A\[\?\?((?:.|\n.|\n(?=\?\?\]))+?)\?\?\]/,
    :cite => /\?\?((?:.|\n.|\n(?=\?\?))+?)\?\?/,
  }

  ALL_MATCHERS = Regexp.union(SYMS.values)
end
