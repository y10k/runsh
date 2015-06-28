#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'test/unit'

module RunSh::Test
  class RunShTest < Test::Unit::TestCase
    def test_scan_token
      assert_equal([], RunSh.scan_token(''))
      assert_equal([ [ :word, 'test' ] ], RunSh.scan_token('test'))
      assert_equal([ [ :sep, "  \t\t\t " ] ], RunSh.scan_token("  \t\t\t "))
      assert_equal([ [ :word, 'test' ], [ :sep, "\n" ] ], RunSh.scan_token("test\n"))
      assert_equal([ [ :word, 'ls' ],
                     [ :sep, ' ' ],
                     [ :word, '-ltr' ],
                     [ :sep, ' ' ],
                     [ :word, '*.txt' ],
                     [ :sep, "\n" ]
                   ], RunSh.scan_token("ls -ltr *.txt\n"))
      assert_equal([ [ :sep, '((' ],
                     [ :sep, ' ' ],
                     [ :sep, '(' ], [ :word, '1' ], [ :sep, ' ' ], [ :word, '+' ], [ :sep, ' ' ], [ :word, '2' ], [ :sep, ')' ],
                     [ :sep, ' ' ], [ :word, '*' ], [ :sep, ' ' ], [ :word, '3' ],
                     [ :sep, ' ' ], [ :word, '/' ], [ :sep, ' ' ], [ :word, '4' ],
                     [ :sep, ' ' ],
                     [ :sep, '))' ]
                   ], RunSh.scan_token('(( (1 + 2) * 3 / 4 ))'))
      assert_equal([ [ :sep, '||' ], [ :sep, '|' ],
                     [ :sep, '&&' ], [ :sep, '&' ],
                     [ :sep, '<' ], [ :sep, '>' ],
                     [ :sep, '((' ], [ :sep, '(' ],
                     [ :sep, '))' ], [ :sep, ')' ],
                     [ :sep, '{{' ], [ :sep, '{' ],
                     [ :sep, '}}' ], [ :sep, '}' ],
                     [ :sep, '$((' ], [ :sep, '))' ],
                     [ :sep, '$(' ], [ :sep, ')' ],
                     [ :sep, '${{' ], [ :sep, '}}' ],
                     [ :sep, '${' ], [ :sep, '}' ],
                     [ :sep, "\\" ], [ :sep, '$' ]
                   ], RunSh.scan_token(%w[ ||| &&& <> ((( ))) {{{ }}} $(()) $() ${{}} ${} \\ $ ].join('')))
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
