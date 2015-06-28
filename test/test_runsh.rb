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
                     [ :sep, '{' ], [ :sep, '}' ],
                     [ :sep, '$((' ], [ :sep, '))' ],
                     [ :sep, '$(' ], [ :sep, ')' ],
                     [ :sep, '${' ], [ :sep, '}' ],
                     [ :sep, "\\" ], [ :sep, '$' ]
                   ], RunSh.scan_token(%w[ ||| &&& <> ((( ))) {} $(()) $() ${} \\ $ ].join('')))
    end

    def test_command_parser
      parser = RunSh::CommandParser.new
      assert_equal([ [ :run, 'test' ] ],
                   parser.scan_line([ [ :word, 'test' ] ]).to_a)
      assert_equal([ [ :run, 'test' ] ],
                   parser.scan_line([ [ :word, 'test' ],
                                      [ :sep, "\n" ]
                                    ]).to_a)
      assert_equal([ [ :run, 'test', '-f', 'foo.txt' ],
                     [ :run, 'test', '-f', 'bar.txt' ]
                   ],
                   parser.scan_line([ [ :word, 'test' ], [ :sep, ' ' ], [ :word, '-f' ], [ :sep, ' ' ], [ :word, 'foo.txt' ],
                                      [ :sep, ';' ],
                                      [ :word, 'test' ], [ :sep, '  ' ], [ :word, '-f' ], [ :sep, "\t" ], [ :word, 'bar.txt' ],
                                      [ :sep, "\n" ]
                                    ]).to_a)
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
