#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'test/unit'

module RunSh::Test
  class CommandParserTest < Test::Unit::TestCase
    def setup
      @parser = RunSh::CommandParser.new
    end

    def assert_command_parse(*expected_parsed_list, script_text)
      assert_equal(expected_parsed_list, @parser.parse!(script_text.dup).to_a)
    end
    private :assert_command_parse

    def test_parse_empty
      assert_command_parse('')
    end

    def test_parse_newline
      assert_command_parse("\n")
    end

    def test_parse_minimal_command
      assert_command_parse([ :cmd, [ [ :s, 'foo' ] ] ],
                           "foo\n")

      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :s, 'bar' ] ],
                           ],
                           " foo bar \n")
    end

    def test_parse_command_list
      assert_command_parse([ :cmd, [ [ :s, 'foo' ] ] ],
                           [ :cmd, [ [ :s, 'bar' ] ] ],
                           "foo;bar\n")

      assert_command_parse([ :cmd, [ [ :s, 'foo' ] ] ],
                           [ :cmd, [ [ :s, 'bar' ] ] ],
                           " foo ; bar ; \n")
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
