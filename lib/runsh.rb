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
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
