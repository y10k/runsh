#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'stringio'
require 'test/unit'

module RunSh::Test
  class SyntaxStructTest < Test::Unit::TestCase
    include RunSh::SyntaxStruct

    def setup
      @c = RunSh::ScriptContext.new
      @i = RunSh::CommandInterpreter.new(@c)
    end

    def test_command_list_empty
      assert_equal([], CommandList.new.to_cmd_exec_list(@i, @c))
    end

    def test_command_list_simple
      assert_equal(%w[ echo HALO ],
                   CommandList.new.
                   add(FieldList.new.add('echo')).
                   add(FieldList.new.add('HALO')).
                   to_cmd_exec_list(@i, @c))
    end

    def test_command_list_single_quote
      assert_equal([ 'echo', 'Hello world.' ],
                   CommandList.new.
                   add(FieldList.new.add('echo')).
                   add(FieldList.new.add(QuotedString.new.add('Hello world.'))).
                   to_cmd_exec_list(@i, @c))
    end

    def test_command_list_double_quote
      assert_equal([ 'echo', 'Hello world.' ],
                   CommandList.new.
                   add(FieldList.new.add('echo')).
                   add(FieldList.new.add(DoubleQuotedList.new.add('Hello world.'))).
                   to_cmd_exec_list(@i, @c))
    end

    def test_command_list_mixed
      assert_equal([ 'echo', 'Hello world.' ],
                   CommandList.new.
                   add(FieldList.new.add('echo')).
                   add(FieldList.new.
                       add('Hello').
                       add(QuotedString.new.add(' ')).
                       add(DoubleQuotedList.new.add('world')).
                       add('.')).
                   to_cmd_exec_list(@i, @c))
    end
  end

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

    def test_comment
      parse_script("# here is comment: ${('\"`;&|<>\n") {
        assert_parse(CommandList.new(eoc: "\n"))
      }

      parse_script("echo HALO # here is comment: : ${('\"`;&|<>") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add('HALO')))
      }
    end

    def test_escape
      parse_script("echo Hello\\ world.") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add('Hello').
                         add(QuotedString.new.add(' ')).
                         add('world.')))
      }

      parse_script("echo \\\n\tHALO") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add('HALO')))
      }

      parse_script("echo \\#foo") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(QuotedString.new.add('#')).
                         add('foo')))
      }
    end

    def test_single_quote
      parse_script("echo 'Hello world.'") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(QuotedString.new.add('Hello world.'))))
      }

      parse_script("echo 'foo\nbar'") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(QuotedString.new.add("foo\nbar"))))
      }

      parse_script("echo '#foo'") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(QuotedString.new.add('#foo'))))
      }
    end

    def test_double_quote
      parse_script(%Q'echo "Hello world."') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(DoubleQuotedList.new.add('Hello world.'))))
      }

      parse_script(%Q'echo "\\"Hello world.\\""') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(DoubleQuotedList.new.add('"Hello world."'))))
      }

      parse_script(%Q'echo "foo\nbar"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(DoubleQuotedList.new.add("foo\nbar"))))
      }

      parse_script(%Q'echo "foo,\\\nbar"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(DoubleQuotedList.new.add("foo,bar"))))
      }

      parse_script(%Q'echo "#foo"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(DoubleQuotedList.new.add('#foo'))))
      }
    end

    def test_mixed
      parse_script("echo Hello\\ \"world\".") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add('Hello').
                         add(QuotedString.new.add(' ')).
                         add(DoubleQuotedList.new.add('world')).
                         add('.')))
      }
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
