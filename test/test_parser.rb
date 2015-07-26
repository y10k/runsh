#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'stringio'
require 'test/unit'

module RunSh::Test
  class CommandParserTest < Test::Unit::TestCase
    include RunSh::SyntaxStruct

    def parse_script(script_text)
      token_scanner = RunSh::TokenScanner.new(StringIO.new(script_text))
      @cmd_parser = RunSh::CommandParser.new(token_scanner.scan_token)
      yield
    end
    private :parse_script

    def assert_parse(expected_list, parse_method=:parse_command)
      assert_equal(expected_list, @cmd_parser.send(parse_method))
    end

    def test_simple_command
      parse_script("echo HALO") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add('HALO')))
      }

      parse_script("foo; bar\n") {
        assert_parse(CommandList.new(eoc: ';').
                     add(FieldList.new.add('foo')))
        assert_parse(CommandList.new(eoc: "\n").
                     add(FieldList.new.add('bar')))
      }
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
