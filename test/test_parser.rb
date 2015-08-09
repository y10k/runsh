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

    def assert_syntax(expected_result, cmd_syntax)
      assert_equal(expected_result,
                   RunSh::SyntaxStruct.expand(cmd_syntax, @c, @i))
    end
    private :assert_syntax

    def assert_syntax_error(expected_error_type, expected_error_message, cmd_syntax)
      begin
        RunSh::SyntaxStruct.expand(cmd_syntax, @c, @i)
      rescue
        assert_instance_of(expected_error_type, $!)
        assert(($!.message.end_with? expected_error_message),
               "expected <#{expected_error_message}> but was <#{$!.message}>.")
        return
      end
      flunk('no error!')
    end
    private :assert_syntax

    def test_command_list_empty
      assert_syntax([], CommandList.new)
    end

    def test_command_list_simple
      assert_syntax(%w[ echo HALO ],
                    CommandList.new.
                    add(FieldList.new.add('echo')).
                    add(FieldList.new.add('HALO')))
    end

    def test_command_list_single_quote
      assert_syntax([ 'echo', 'Hello world.' ],
                    CommandList.new.
                    add(FieldList.new.add('echo')).
                    add(FieldList.new.add(QuotedString.new.add('Hello world.'))))
    end

    def test_command_list_double_quote
      assert_syntax([ 'echo', 'Hello world.' ],
                    CommandList.new.
                    add(FieldList.new.add('echo')).
                    add(FieldList.new.add(DoubleQuotedList.new.add('Hello world.'))))
    end

    def test_command_list_mixed
      assert_syntax([ 'echo', 'Hello world.' ],
                    CommandList.new.
                    add(FieldList.new.add('echo')).
                    add(FieldList.new.
                        add('Hello').
                        add(QuotedString.new.add(' ')).
                        add(DoubleQuotedList.new.add('world')).
                        add('.')))
    end

    def test_parameter_expansion_plain_name
      @c.put_var('foo', 'HALO')
      assert_syntax('HALO', ParameterExansion.new(name: 'foo'))

      @c.unset_var('foo')
      assert_syntax('', ParameterExansion.new(name: 'foo'))
    end

    def test_parameter_expansion_program_name
      @c.program_name = 'foo'
      assert_syntax('foo', ParameterExansion.new(name: '0'))
    end

    def test_parameter_expansion_args
      assert_syntax('0', ParameterExansion.new(name: '#'))
      assert_syntax('', ParameterExansion.new(name: '@'))
      assert_syntax('', ParameterExansion.new(name: '*'))
      assert_syntax('', ParameterExansion.new(name: '1'))
      assert_syntax('', ParameterExansion.new(name: '2'))
      assert_syntax('', ParameterExansion.new(name: '3'))

      @c.args = %w[ foo bar baz ]
      assert_syntax('3', ParameterExansion.new(name: '#'))
      assert_syntax('foo bar baz', ParameterExansion.new(name: '@'))
      assert_syntax('foo bar baz', ParameterExansion.new(name: '*'))
      assert_syntax('foo', ParameterExansion.new(name: '1'))
      assert_syntax('bar', ParameterExansion.new(name: '2'))
      assert_syntax('baz', ParameterExansion.new(name: '3'))
    end

    def test_parameter_expansion_pid
      @c.pid = 1234
      assert_syntax('1234', ParameterExansion.new(name: '$'))
    end

    def test_parameter_expansion_command_status
      assert_syntax('0', ParameterExansion.new(name: '?'))

      @c.command_status = 1
      assert_syntax('1', ParameterExansion.new(name: '?'))
    end

    def test_parameter_expansion_string_length
      assert_syntax('0', ParameterExansion.new(name: '#foo'))

      @c.put_var('foo', 'Hello world.')
      assert_syntax('12', ParameterExansion.new(name: '#foo'))
    end

    def test_parameter_expansion_use_default_value
      assert_syntax('HALO', ParameterExansion.new(name: 'foo', separator: ':-').add('HALO'))
      assert_nil(@c.get_var('foo'))

      @c.put_var('foo', '')
      assert_syntax('HALO', ParameterExansion.new(name: 'foo', separator: ':-').add('HALO'))
      assert_equal('', @c.get_var('foo'))

      @c.put_var('foo', 'Hello world.')
      assert_syntax('Hello world.', ParameterExansion.new(name: 'foo', separator: ':-').add('HALO'))
      assert_equal('Hello world.', @c.get_var('foo'))

      assert_syntax('HALO', ParameterExansion.new(name: 'bar', separator: '-').add('HALO'))
      assert_nil(@c.get_var('bar'))

      @c.put_var('bar', '')
      assert_syntax('', ParameterExansion.new(name: 'bar', separator: '-').add('HALO'))
      assert_equal('', @c.get_var('bar'))
    end

    def test_parameter_expansion_assign_default_value
      assert_syntax('HALO', ParameterExansion.new(name: 'foo', separator: ':=').add('HALO'))
      assert_equal('HALO', @c.get_var('foo'))

      @c.put_var('foo', '')
      assert_syntax('HALO', ParameterExansion.new(name: 'foo', separator: ':=').add('HALO'))
      assert_equal('HALO', @c.get_var('foo'))

      @c.put_var('foo', 'Hello world.')
      assert_syntax('Hello world.', ParameterExansion.new(name: 'foo', separator: ':=').add('HALO'))
      assert_equal('Hello world.', @c.get_var('foo'))

      assert_syntax('HALO', ParameterExansion.new(name: 'bar', separator: '=').add('HALO'))
      assert_equal('HALO', @c.get_var('bar'))

      @c.put_var('bar', '')
      assert_syntax('', ParameterExansion.new(name: 'bar', separator: '=').add('HALO'))
      assert_equal('', @c.get_var('bar'))
    end

    def test_parameter_expansion_indicate_error
      assert_syntax_error(RuntimeError, 'foo',
                          ParameterExansion.new(name: 'foo', separator: ':?'))
      assert_syntax_error(RuntimeError, 'foo: HALO',
                          ParameterExansion.new(name: 'foo', separator: ':?').add('HALO'))
      assert_nil(@c.get_var('foo'))

      @c.put_var('foo', '')
      assert_syntax_error(RuntimeError, 'foo',
                          ParameterExansion.new(name: 'foo', separator: ':?'))
      assert_syntax_error(RuntimeError, 'foo: HALO',
                          ParameterExansion.new(name: 'foo', separator: ':?').add('HALO'))
      assert_equal('', @c.get_var('foo'))

      @c.put_var('foo', 'Hello world.')
      assert_syntax('Hello world.', ParameterExansion.new(name: 'foo', separator: ':?'))
      assert_syntax('Hello world.', ParameterExansion.new(name: 'foo', separator: ':?').add('HALO'))
      assert_equal('Hello world.', @c.get_var('foo'))

      assert_syntax_error(RuntimeError, 'bar',
                          ParameterExansion.new(name: 'bar', separator: '?'))
      assert_syntax_error(RuntimeError, 'bar: HALO',
                          ParameterExansion.new(name: 'bar', separator: '?').add('HALO'))
      assert_nil(@c.get_var('bar'))

      @c.put_var('bar', '')
      assert_syntax('Hello world.', ParameterExansion.new(name: 'foo', separator: '?'))
      assert_syntax('Hello world.', ParameterExansion.new(name: 'foo', separator: '?').add('HALO'))
      assert_equal('', @c.get_var('bar'))
    end

    def test_parameter_expansion_use_alternative_value
      assert_syntax('', ParameterExansion.new(name: 'foo', separator: ':+').add('HALO'))
      assert_nil(@c.get_var('foo'))

      @c.put_var('foo', '')
      assert_syntax('', ParameterExansion.new(name: 'foo', separator: ':+').add('HALO'))
      assert_equal('', @c.get_var('foo'))

      @c.put_var('foo', 'Hello world.')
      assert_syntax('HALO', ParameterExansion.new(name: 'foo', separator: ':+').add('HALO'))
      assert_equal('Hello world.', @c.get_var('foo'))

      assert_syntax('', ParameterExansion.new(name: 'bar', separator: '+').add('HALO'))
      assert_nil(@c.get_var('bar'))

      @c.put_var('bar', '')
      assert_syntax('HALO', ParameterExansion.new(name: 'bar', separator: '+').add('HALO'))
      assert_equal('', @c.get_var('bar'))
    end

    def test_parameter_expansion_nested_parameter_expansion
      @c.put_var('foo', 'Hello world.')
      assert_syntax('[Hello world.]',
                    ParameterExansion.new(name: 'bar', separator: ':-').
                    add('[').
                    add(ParameterExansion.new(name: 'foo')).
                    add(']'))
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

    def test_parameter_expansion
      parse_script('echo $#') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '#'))))
      }

      parse_script('echo $@') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '@'))))
      }

      parse_script('echo $*') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '*'))))
      }

      parse_script('echo $?') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '?'))))
      }

      parse_script('echo $-') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '-'))))
      }

      parse_script('echo $$') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '$'))))
      }

      parse_script('echo $!') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '!'))))
      }

      parse_script('echo $0') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '0'))))
      }

      parse_script('echo $1') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '1'))))
      }

      parse_script('echo $foo') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo'))))
      }
    end

    def test_parameter_expansion_double_quote
      parse_script('echo "$#"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '#')))))
      }

      parse_script('echo "$@"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '@')))))
      }

      parse_script('echo "$*"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '*')))))
      }

      parse_script('echo "$?"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '?')))))
      }

      parse_script('echo "$-"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '-')))))
      }

      parse_script('echo "$$"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '$')))))
      }

      parse_script('echo "$!"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '!')))))
      }

      parse_script('echo "$0"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '0')))))
      }

      parse_script('echo "$1"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '1')))))
      }

      parse_script('echo "$foo"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: 'foo')))))
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
