#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'test/unit'

module RunSh::Test
  class SyntaxStructTest < Test::Unit::TestCase
    include RunSh::SyntaxStruct

    def setup
      @c = RunSh::ScriptContext.new
      @i = RunSh::CommandInterpreter.new(@c)
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
end

# Local Variables:
# indent-tabs-mode: nil
# End:
