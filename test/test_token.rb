#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'stringio'
require 'test/unit'

module RunSh::Test
  class TokenScannerTest < Test::Unit::TestCase
    def assert_token_scan(expected_token_list, script_text)
      token_scanner = RunSh::TokenScanner.new(StringIO.new(script_text))
      assert_equal(expected_token_list,
                   token_scanner.scan_token.map{|token| [ token.name, token.value ] })
    end

    def test_simple_command
      assert_token_scan([ [ :word, 'echo' ] ], 'echo')
    end

    def test_single_quote
      assert_token_scan([ [ :word, 'echo' ],
                          [ :space, ' ' ],
                          [ :quote, "'" ],
                          [ :word, 'Hello' ],
                          [ :space, ' ' ],
                          [ :word, 'world.' ],
                          [ :quote, "'" ],
                          [ :cmd_term, "\n" ]
                        ],
                        "echo 'Hello world.'\n")
    end

    def test_double_quote
      assert_token_scan([ [ :word, 'echo' ],
                          [ :space, ' ' ],
                          [ :qquote, '"' ],
                          [ :word, 'Hello' ],
                          [ :space, ' ' ],
                          [ :word, 'world.' ],
                          [ :qquote, '"' ],
                          [ :cmd_term, "\n" ]
                        ],
                        %Q'echo "Hello world."\n')
    end

    def test_escape
      assert_token_scan([ [ :word, 'echo' ],
                          [ :space, ' ' ],
                          [ :word, 'Hello' ],
                          [ :escape, "\\ " ],
                          [ :word, 'world.' ],
                          [ :cmd_term, "\n" ]
                        ],
                        "echo Hello\\ world.\n")

      assert_token_scan([ [ :word, 'echo' ],
                          [ :space, ' ' ],
                          [ :escape, "\\\n" ],
                          [ :space, "\t" ],
                          [ :word, 'HALO' ],
                          [ :cmd_term, "\n" ]
                        ],
                        "echo \\\n" +
                        "\tHALO\n")
    end

    def test_command_separator
      assert_token_scan([ [ :word, 'foo' ],
                          [ :cmd_sep, ';' ],
                          [ :word, 'bar' ],
                          [ :cmd_term, "\n" ]
                        ],
                        "foo;bar\n")
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
