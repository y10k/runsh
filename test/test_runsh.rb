#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'test/unit'

module RunSh::Test
  class RunShTest < Test::Unit::TestCase
    def test_scan_token
      assert_equal([], RunSh.scan_token(''))
      assert_equal([ [ :word, 'foo' ] ], RunSh.scan_token('foo'))
      assert_equal([ [ :space, "  \t " ] ], RunSh.scan_token("  \t "))
      assert_equal([ [ :newline, "\n" ] ], RunSh.scan_token("\n"))
      assert_equal([ [ :special, ';' ] ], RunSh.scan_token(';'))

      assert_equal([ [ :word, 'foo' ],
                     [ :special, ';' ],
                     [ :space, ' ' ],
                     [ :word, 'bar' ],
                     [ :newline, "\n" ]
                   ], RunSh.scan_token("foo; bar\n"))
    end

    def test_command_parser
      parser = RunSh::CommandParser.new
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
