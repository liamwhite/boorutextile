# frozen_string_literal: true
require 'textile/nodes'

module TextileParser
  extend self

  def parse(text)
    ary = []
    operand(ary, text) until text.empty?
    MultiNode.new(ary)
  end

  def find_syms(text)
    # Find possible symbol matches
    syms = SYM_TO_INDEX.map    { |sym, index| [sym, text.index(index)] }
                       .reject { |sym, index| index.nil? }

    # Find closest to start of string
    min = syms.map{ |x| x[1] }.min

    # Get associated regexps and find first
    matchdata = nil
    match = syms.select { |sym, index| index == min }
                .map    { |sym, index| [sym, SYM_TO_REGEX[sym]] }
                .detect { |sym, re| matchdata = re.match(text) }

    # [sym, matchdata]
    [match[0], matchdata] if match
  end

  def operand(ary, text)
    sym, md = find_syms(text)
    if sym.nil? || md.nil?
      # No match, consume entire string.
      return ary << TextNode.new(text.slice!(0 .. text.length))
    end

    # Consume string before match.
    if md.pre_match.size > 0
      ary << TextNode.new(text.slice!(0 ... md.pre_match.size))
    end

    # Act on match.
    # FIXME: Separate logic for string consumption:
    case sym
    when :raw_bracket
      balanced = balance_markup(text, md.to_s, '[==', '==]').match(SYM_TO_REGEX[:raw_bracket])[1]
      ary << RawTextNode.new(balanced)
    when :bq_author
      balanced = balance_markup(text, md.to_s, BQ_LEFT, '[/bq]').match(SYM_TO_REGEX[:bq_author])[2]
      ary << HTMLNode.new(:blockquote, parse(balanced), title: $1)
    when :bq
      balanced = balance_markup(text, md.to_s, BQ_LEFT, '[/bq]').match(SYM_TO_REGEX[:bq])[1]
      ary << HTMLNode.new(:blockquote, parse(balanced))
    when :spoiler
      balanced = balance_markup(text, md.to_s, '[spoiler]', '[/spoiler]').match(SYM_TO_REGEX[:spoiler])[1]
      ary << HTMLNode.new(:span, parse(balanced), class: 'spoiler')
    else
      text.slice!(0 .. md.to_s.size)
    end

    case sym
    when :raw
      ary << RawTextNode.new(md[1])
    when :link_title_bracket, :link_title
      ary << HTMLNode.new(:a, parse(md[1]), title: md[2], href: md[3])
    when :link_bracket, :link
      ary << HTMLNode.new(:a, parse(md[1]), href: md[2])
    when :image_link_title_bracket, :image_link_title
      ary << HTMLNode.new(:a, ImageNode.new(md[1]), title: md[2], href: md[3])
    when :image_link_bracket, :image_link
      ary << HTMLNode.new(:a, ImageNode.new(md[1]), href: md[2])
    when :image_title_bracket, :image_title
      ary << HTMLNode.new(:span, ImageNode.new(md[1]), title: md[2])
    when :image_bracket, :image
      ary << ImageNode.new(md[1])
    when :dblbold_bracket, :dblbold
      ary << HTMLNode.new(:b, parse(md[1]))
    when :bold_bracket, :bold
      ary << HTMLNode.new(:strong, parse(md[1]))
    when :dblitalic_bracket, :dblitalic
      ary << HTMLNode.new(:i, parse(md[1]))
    when :italic_bracket, :italic
      ary << HTMLNode.new(:em, parse(md[1]))
    when :code_bracket, :code
      ary << HTMLNode.new(:code, parse(md[1]))
    when :ins_bracket, :ins
      ary << HTMLNode.new(:ins, parse(md[1]))
    when :sup_bracket, :sup
      ary << HTMLNode.new(:sup, parse(md[1]))
    when :del_bracket, :del
      ary << HTMLNode.new(:del, parse(md[1]))
    when :sub_bracket, :sub
      ary << HTMLNode.new(:sub, parse(md[1]))
    when :cite_bracket, :cite
      ary << HTMLNode.new(:cite, parse(md[1]))
    end
  end

  private

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

  # Symbol table, in operator precedence order:
  #   0. Symbol name.
  #   1. Start string for optimized matching.
  #   2. Complete match definition.
  SYMS = [
    [:raw_bracket, '[==',       /\[==(.*)==\]/],
    [:bq_author,   '[bq="',     /\[bq="([^"]*)"\](.*)\[\/bq\]/],
    [:bq,          '[bq]',      /\[bq\](.*)\[\/bq\]/],
    [:spoiler,     '[spoiler]', /\[spoiler\](.*)\[\/spoiler\]/],
    [:raw,         '==',        /==(.*)==/],

    [:link_title_bracket, '["', /\A\["([^"]*)\(([^\)]*)\)":(#{RX_URL})\]/],
    [:link_title,         '"',  /"([^"]*)\(([^\)]*)\)":(#{RX_URL})/],
    [:link_bracket,       '["', /\["([^"]*)":(#{RX_URL})\]/],
    [:link,               '"',  /"([^"]*)":(#{RX_URL})/],

    [:image_link_title_bracket, '[!', /\[!(#{RX_URL})\(([^\)]*)\)!:(#{RX_URL})\]/],
    [:image_link_title,         '!',  /!(#{RX_URL})\(([^\)]*)\)!:(#{RX_URL})/],
    [:image_link_bracket,       '[!', /\[!(#{RX_URL})!:(#{RX_URL})\]/],
    [:image_link,               '!',  /!(#{RX_URL})!:(#{RX_URL})/],
    [:image_title_bracket,      '[!', /\[!(#{RX_URL})\(([^\)]*)\)!\]/],
    [:image_title,              '!',  /!(#{RX_URL})\(([^\)]*)\)!/],
    [:image_bracket,            '[!', /\[!(#{RX_URL})!\]/],
    [:image,                    '!',  /!(#{RX_URL})!/],

    [:dblbold_bracket,   '[**', /\[\*\*((?:.|\n.|\n(?=\*\*\]))+?)\*\*\]/],
    [:dblbold,           '**',  /\*\*((?:.|\n.|\n(?=\*\*))+?)\*\*/],
    [:bold_bracket,      '[*',  /\[\*((?:.|\n.|\n(?=\*\]))+?)\*\]/],
    [:bold,              '*',   /\*((?:.|\n.|\n(?=\*\]))+?)\*/],
    [:dblitalic_bracket, '[__', /\[__((?:.|\n.|\n(?=__\]))+?)__\]/],
    [:dblitalic,         '__',  /__((?:.|\n.|\n(?=__))+?)__/],
    [:italic_bracket,    '[_',  /\A\[_((?:.|\n.|\n(?=_\]))+?)_\]/],
    [:italic,            '_',   /_((?:.|\n.|\n(?=_))+?)_/],
    [:code_bracket,      '[@',  /\[@((?:.|\n.|\n(?=@\]))+?)@\]/],
    [:code,              '@',   /@((?:.|\n.|\n(?=@))+?)@/],
    [:ins_bracket,       '[+',  /\A\[\+((?:.|\n.|\n(?=\+\]))+?)\+\]/],
    [:ins,               '+',   /\+((?:.|\n.|\n(?=\+))+?)\+/],
    [:sup_bracket,       '[^',  /\A\[\^((?:.|\n.|\n(?=\^\]))+?)\^\]/],
    [:sup,               '^',   /\^((?:.|\n.|\n(?=\^))+?)\^/],
    [:del_bracket,       '[-',  /\A\[\-((?:.|\n.|\n(?=\-\]))+?)\-\]/],
    [:del,               '-',   /\-((?:.|\n.|\n(?=\-))+?)\-/],
    [:sub_bracket,       '[~',  /\A\[\~((?:.|\n.|\n(?=\~\]))+?)\~\]/],
    [:sub,               '~',   /\~((?:.|\n.|\n(?=\~))+?)\~/],
    [:cite_bracket,      '[??', /\A\[\?\?((?:.|\n.|\n(?=\?\?\]))+?)\?\?\]/],
    [:cite,              '??',  /\?\?((?:.|\n.|\n(?=\?\?))+?)\?\?/],
  ]

  SYM_TO_INDEX = Hash[SYMS.map { |name, index, re| [name, index] }]
  SYM_TO_REGEX = Hash[SYMS.map { |name, index, re| [name, re]    }]
end
