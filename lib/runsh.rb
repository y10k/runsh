# -*- coding: utf-8 -*-

require 'runsh/version'

module RunSh
  SPECIAL_SEPARATORS = %w[
    || |  &&  &
    <  >
    (( )) (  )  {{ }} { }
    $(( $( ${{ ${ $
    ` \\  "
    ;
  ]

  SEPARATOR_SCAN_PATTEN = /
    (?<word> .*?)
    (?<separator>
      (?:
        #{SPECIAL_SEPARATORS.map{|s| Regexp.quote(s) }.join('|')} |
        [\ \t]+ |
        \n |
        \Z
      )
    )
  /mx

  def scan_token(source_text)
    token_list = []
    source_text.scan(SEPARATOR_SCAN_PATTEN) do
      token_list.push([ :word, $~[:word] ]) unless $~[:word].empty?
      token_list.push([ :sep, $~[:separator] ]) unless $~[:separator].empty?
    end

    token_list
  end
  module_function :scan_token

  class CommandParser
    def scan_line(token_list)
      return enum_for(:scan_line, token_list) unless block_given?

      cmd = [ :run ]
      while (token = token_list.shift)
        case (token[0])
        when :word
          cmd << token[1]
        when :sep
          case (token[1])
          when ';', "\n"
            yield(cmd)
            cmd = [ :run ]
          when /^[\ \t]+$/
            # skipped
          else
            cmd << token[1]
          end
        else
          raise "unknown token: #{token.join(', ')}"
        end
      end

      if (cmd.length > 1) then
        yield(cmd)
      end

      self
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
