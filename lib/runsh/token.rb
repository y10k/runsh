# -*- coding: utf-8 -*-

require 'strscan'

module RunSh
  class TokenScanner
    Token = Struct.new(:name, :value)
    TokenNamePatternPair = Struct.new(:name, :pattern)

    TOKEN_PATTERN_LIST = []

    def self.def_token(name, pattern)
      TOKEN_PATTERN_LIST << TokenNamePatternPair.new(name, pattern)
    end

    def_token :param_begin, /\${/
    def_token :param, /\$ (?: \# | @ | \* | \? | - | \$ | ! | [0-9] | [_A-Za-z][_A-Za-z0-9]* )/x
    def_token :word, /\$/       # unmatched parameter expansion

    def_token :group_begin, /{/
    def_token :group_end, /}/
    def_token :space, /[ \t]+/
    def_token :quote, /'/
    def_token :qquote, /"/
    def_token :escape, /\\./m
    def_token :cmd_sep, /;/
    def_token :cmd_term, /\n/

    special_chars = [
      '$',                      # parameter expansion
      '{', '}',                 # group begin/end
      ' ', "\t",                # space
      "'", '"',                 # quote/qquote
      "\\",                     # escape
      ';', "\n"                 # command separator/terminator
    ]

    def_token :word, /[^#{special_chars.map{|c| Regexp.quote(c) }.join('')}]+/

    def initialize(input)
      @input = input
    end

    def scan_token
      return enum_for(:scan_token) unless block_given?
      while (line = @input.gets)
        strscan = StringScanner.new(line)
        until (strscan.eos?)
          catch (:found_token) {
            for token_pair in TOKEN_PATTERN_LIST
              if (token_value = strscan.scan(token_pair.pattern)) then
                yield(Token.new(token_pair.name, token_value))
                throw(:found_token)
              end
            end
            raise "syntax error: #{strscan.rest.inspect}"
          }
        end
      end
      self
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
