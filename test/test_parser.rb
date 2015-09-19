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

    def new_string_length_visitor
      StringLengthVisitor.new(@c, @i)
    end
    private :new_string_length_visitor

    def test_string_length_visitor
      assert_equal(0, DoubleQuotedList.new.accept(new_string_length_visitor))
      assert_equal(0, ReplaceHolder.new.accept(new_string_length_visitor))
      assert_equal(0, FieldList.new.accept(new_string_length_visitor))

      assert_equal(3,
                   DoubleQuotedList.new.
                   add('1').
                   add(QuotedString.new.add('23')).
                   accept(new_string_length_visitor))

      assert_equal(6,
                   ReplaceHolder.new.
                   add('1').
                   add(QuotedString.new.add('23')).
                   add(DoubleQuotedList.new.add('456')).
                   accept(new_string_length_visitor))

      assert_equal(6,
                   FieldList.new.
                   add(ReplaceHolder.new.
                       add('1').
                       add(QuotedString.new.add('23')).
                       add(DoubleQuotedList.new.add('456'))).
                   accept(new_string_length_visitor))
    end

    def new_to_string_visitor
      ToStringVisitor.new(@c, @i)
    end
    private :new_to_string_visitor

    def test_to_string_visitor
      assert_equal('', DoubleQuotedList.new.accept(new_to_string_visitor))
      assert_equal('', ReplaceHolder.new.accept(new_to_string_visitor))
      assert_equal('', FieldList.new.accept(new_to_string_visitor))

      assert_equal('abc',
                   DoubleQuotedList.new.
                   add('a').
                   add(QuotedString.new.add('bc')).
                   accept(new_to_string_visitor))

      assert_equal('abcdef',
                   ReplaceHolder.new.
                   add('a').
                   add(QuotedString.new.add('bc')).
                   add(DoubleQuotedList.new.add('def')).
                   accept(new_to_string_visitor))

      assert_equal('abcdef',
                   FieldList.new.
                   add(ReplaceHolder.new.
                       add('a').
                       add(QuotedString.new.add('bc')).
                       add(DoubleQuotedList.new.add('def'))).
                   accept(new_to_string_visitor))
    end

    def new_replace_visitor
      ReplaceVisitor.new(@c, @i)
    end
    private :new_replace_visitor

    def assert_replace(expected_syntax_tree, syntax_tree)
      assert_equal(expected_syntax_tree,
                   syntax_tree.accept(new_replace_visitor))
    end
    private :assert_replace

    def test_replace_visitor_simple
      assert_replace(CommandList.new, CommandList.new)
      assert_replace(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add('Hello').
                         add(QuotedString.new.add(' ')).
                         add(DoubleQuotedList.new.add('world.'))),
                     CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add('Hello').
                         add(QuotedString.new.add(' ')).
                         add(DoubleQuotedList.new.add('world.'))))
    end

    def test_replace_visitor_parameter_expansion_plain_name
      assert_replace(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ReplaceHolder.new)),
                     CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo'))))

      @c.put_var('foo', 'HALO')
      assert_replace(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ReplaceHolder.new.add('HALO'))),
                     CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo'))))
    end

    def test_replace_visitor_parameter_expansion_program_name
      @c.program_name = 'foo'
      assert_replace(ReplaceHolder.new.add('foo'), ParameterExansion.new(name: '0'))
    end

    def test_replace_visitor_parameter_args
      assert_replace(ReplaceHolder.new.add('0'), ParameterExansion.new(name: '#'))
      assert_replace(ReplaceHolder.new, ParameterExansion.new(name: '@'))
      assert_replace(ReplaceHolder.new, ParameterExansion.new(name: '*'))
      assert_replace(ReplaceHolder.new, ParameterExansion.new(name: '1'))
      assert_replace(ReplaceHolder.new, ParameterExansion.new(name: '2'))
      assert_replace(ReplaceHolder.new, ParameterExansion.new(name: '3'))

      @c.args = %w[ foo bar baz ]
      assert_replace(ReplaceHolder.new.add('3'), ParameterExansion.new(name: '#'))
      assert_replace(ReplaceHolder.new.add('foo bar baz'), ParameterExansion.new(name: '@'))
      assert_replace(ReplaceHolder.new.add('foo bar baz'), ParameterExansion.new(name: '*'))
      assert_replace(ReplaceHolder.new.add('foo'), ParameterExansion.new(name: '1'))
      assert_replace(ReplaceHolder.new.add('bar'), ParameterExansion.new(name: '2'))
      assert_replace(ReplaceHolder.new.add('baz'), ParameterExansion.new(name: '3'))
    end

    def test_replace_visitor_parameter_expansion_expansion_pid
      @c.pid = 1234
      assert_replace(ReplaceHolder.new.add('1234'), ParameterExansion.new(name: '$'))
    end

    def test_replace_visitor_parameter_expansion_command_status
      assert_replace(ReplaceHolder.new.add('0'), ParameterExansion.new(name: '?'))

      @c.command_status = 1
      assert_replace(ReplaceHolder.new.add('1'), ParameterExansion.new(name: '?'))
    end

    def test_replace_visitor_parameter_expansion_string_length
      assert_replace(ReplaceHolder.new.add('0'), ParameterExansion.new(name: '#foo'))

      @c.put_var('foo', '')
      assert_replace(ReplaceHolder.new.add('0'), ParameterExansion.new(name: '#foo'))

      @c.put_var('foo', 'Hello world.')
      assert_replace(ReplaceHolder.new.add('12'), ParameterExansion.new(name: '#foo'))
    end

    def test_replace_visitor_parameter_expansion_use_default_value
      assert_replace(ReplaceHolder.new.
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')),
                     ParameterExansion.new(name: 'foo', separator: ':-').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_nil(@c.get_var('foo'))

      assert_replace(ReplaceHolder.new.
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')),
                     ParameterExansion.new(name: 'bar', separator: '-').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_nil(@c.get_var('bar'))

      @c.put_var('foo', '')
      assert_replace(ReplaceHolder.new.
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')),
                     ParameterExansion.new(name: 'foo', separator: ':-').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('', @c.get_var('foo'))

      @c.put_var('bar', '')
      assert_replace(ReplaceHolder.new.add(''),
                     ParameterExansion.new(name: 'bar', separator: '-').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('', @c.get_var('bar'))

      @c.put_var('foo', 'HALO')
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'foo', separator: ':-').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))

      @c.put_var('bar', 'HALO')
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'bar', separator: '-').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
    end

    def test_replace_visitor_parameter_expansion_assign_default_value
      assert_replace(ReplaceHolder.new.add('Hello world.'),
                     ParameterExansion.new(name: 'foo', separator: ':=').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('Hello world.', @c.get_var('foo'))
      
      assert_replace(ReplaceHolder.new.add('Hello world.'),
                     ParameterExansion.new(name: 'bar', separator: '=').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('Hello world.', @c.get_var('bar'))

      @c.put_var('foo', '')
      assert_replace(ReplaceHolder.new.add('Hello world.'),
                     ParameterExansion.new(name: 'foo', separator: ':=').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('Hello world.', @c.get_var('foo'))

      @c.put_var('bar', '')
      assert_replace(ReplaceHolder.new.add(''),
                     ParameterExansion.new(name: 'bar', separator: '=').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('', @c.get_var('bar'))

      @c.put_var('foo', 'HALO')
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'foo', separator: ':=').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))

      @c.put_var('bar', 'HALO')
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'bar', separator: '=').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
    end

    def test_replace_visitor_parameter_expansion_indicate_error
      assert_raise(RuntimeError.new('undefined parameter: foo')) {
        ParameterExansion.new(name: 'foo', separator: ':?').
          accept(new_replace_visitor)
      }
      assert_raise(RuntimeError.new('undefined parameter: foo: Hello world.')) {
        ParameterExansion.new(name: 'foo', separator: ':?').
          add('Hello').
          add(QuotedString.new.add(' ')).
          add(DoubleQuotedList.new.add('world.')).
          accept(new_replace_visitor)
      }
      assert_nil(@c.get_var('foo'))

      assert_raise(RuntimeError.new('undefined parameter: bar')) {
        ParameterExansion.new(name: 'bar', separator: '?').
          accept(new_replace_visitor)
      }
      assert_raise(RuntimeError.new('undefined parameter: bar: Hello world.')) {
        ParameterExansion.new(name: 'bar', separator: '?').
          add('Hello').
          add(QuotedString.new.add(' ')).
          add(DoubleQuotedList.new.add('world.')).
          accept(new_replace_visitor)
      }
      assert_nil(@c.get_var('bar'))

      @c.put_var('foo', '')
      assert_raise(RuntimeError.new('undefined parameter: foo')) {
        ParameterExansion.new(name: 'foo', separator: ':?').
          accept(new_replace_visitor)
      }
      assert_raise(RuntimeError.new('undefined parameter: foo: Hello world.')) {
        ParameterExansion.new(name: 'foo', separator: ':?').
          add('Hello').
          add(QuotedString.new.add(' ')).
          add(DoubleQuotedList.new.add('world.')).
          accept(new_replace_visitor)
      }
      assert_equal('', @c.get_var('foo'))

      @c.put_var('bar', '')
      assert_replace(ReplaceHolder.new.add(''),
                     ParameterExansion.new(name: 'bar', separator: '?'))
      assert_replace(ReplaceHolder.new.add(''),
                     ParameterExansion.new(name: 'bar', separator: '?').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('', @c.get_var('bar'))

      @c.put_var('foo', 'HALO')
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'foo', separator: ':?'))
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'foo', separator: ':?').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('HALO', @c.get_var('foo'))

      @c.put_var('bar', 'HALO')
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'bar', separator: '?'))
      assert_replace(ReplaceHolder.new.add('HALO'),
                     ParameterExansion.new(name: 'bar', separator: '?').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('HALO', @c.get_var('bar'))
    end

    def test_replace_visitor_parameter_expansion_use_alternative_value
      assert_replace(ReplaceHolder.new,
                     ParameterExansion.new(name: 'foo', separator: ':+').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_nil(@c.get_var('foo'))

      assert_replace(ReplaceHolder.new,
                     ParameterExansion.new(name: 'bar', separator: '+').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_nil(@c.get_var('bar'))

      @c.put_var('foo', '')
      assert_replace(ReplaceHolder.new,
                     ParameterExansion.new(name: 'foo', separator: ':+').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('', @c.get_var('foo'))

      @c.put_var('bar', '')
      assert_replace(ReplaceHolder.new.
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')),
                     ParameterExansion.new(name: 'bar', separator: '+').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('', @c.get_var('bar'))

      @c.put_var('foo', 'HALO')
      assert_replace(ReplaceHolder.new.
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')),
                     ParameterExansion.new(name: 'foo', separator: ':+').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('HALO', @c.get_var('foo'))

      @c.put_var('bar', 'HALO')
      assert_replace(ReplaceHolder.new.
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')),
                     ParameterExansion.new(name: 'bar', separator: '+').
                     add('Hello').
                     add(QuotedString.new.add(' ')).
                     add(DoubleQuotedList.new.add('world.')))
      assert_equal('HALO', @c.get_var('bar'))
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

    def test_single_token_parameter_expansion
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

    def test_single_token_parameter_expansion_double_quote
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

    def test_parameter_expansion
      parse_script('echo ${#}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '#'))))
      }

      parse_script('echo ${@}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '@'))))
      }
      parse_script('echo ${*}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '*'))))
      }

      parse_script('echo ${?}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '?'))))
      }

      parse_script('echo ${-}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '-'))))
      }

      parse_script('echo ${$}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '$'))))
      }

      parse_script('echo ${!}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '!'))))
      }

      parse_script('echo ${0}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '0'))))
      }

      parse_script('echo ${1}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '1'))))
      }

      parse_script('echo ${10}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: '10'))))
      }

      parse_script('echo ${foo}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo'))))
      }

      parse_script('echo abc${foo}def') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add('abc').
                         add(ParameterExansion.new(name: 'foo')).
                         add('def')))
      }
    end

    def test_parameter_expansion_double_quote
      parse_script('echo "${#}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '#')))))
      }

      parse_script('echo "${@}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '@')))))
      }

      parse_script('echo "${*}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '*')))))
      }

      parse_script('echo "${?}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '?')))))
      }

      parse_script('echo "${-}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '-')))))
      }

      parse_script('echo "${$}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '$')))))
      }

      parse_script('echo "${!}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '!')))))
      }

      parse_script('echo "${0}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '0')))))
      }

      parse_script('echo "${1}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '1')))))
      }

      parse_script('echo "${10}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: '10')))))
      }

      parse_script('echo "${foo}"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add(ParameterExansion.new(name: 'foo')))))
      }

      parse_script('echo "abc ${foo} def"') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.
                         add(DoubleQuotedList.new.
                             add('abc ').
                             add(ParameterExansion.new(name: 'foo')).
                             add(' def'))))
      }
    end

    def test_parameter_expansion_default
      parse_script('echo ${foo:-Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':-').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo-Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '-').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo:=Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':=').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo=Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '=').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo:?Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':?').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo?Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '?').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo:+Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':+').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo+Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '+').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo%%Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '%%').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo%Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '%').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo##Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '##').
                                           add('Hello world.'))))
      }

      parse_script('echo ${foo#Hello world.}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: '#').
                                           add('Hello world.'))))
      }
    end

    def test_parameter_expansion_default_special_token
      parse_script('echo ${foo:-}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':-'))))
      }

      parse_script(%q"echo ${foo:-'Hello world.'}") {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':-').
                                           add(QuotedString.new.add('Hello world.')))))
      }

      parse_script('echo ${foo:-"Hello world."}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':-').
                                           add(DoubleQuotedList.new.add('Hello world.')))))
      }

      parse_script('echo ${foo:-${bar}}') {
        assert_parse(CommandList.new.
                     add(FieldList.new.add('echo')).
                     add(FieldList.new.add(ParameterExansion.new(name: 'foo', separator: ':-').
                                           add(ParameterExansion.new(name: 'bar')))))
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
