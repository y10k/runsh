#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'test/unit'

module RunSh::Test
  class CommandParserTest < Test::Unit::TestCase
    def test_compact_field_list!
      assert_equal([ [ :s, 'foo' ] ],
                   RunSh::CommandParser.compact_command_field!([ [ :s, 'foo' ] ]))

      assert_equal([ [ :s, 'foo' ] ],
                   RunSh::CommandParser.compact_command_field!([ [ :s, 'f' ],
                                                                 [ :s, 'o' ],
                                                                 [ :s, 'o' ]
                                                               ]))

      assert_equal([ [ :s, 'foo' ],
                     [ :other, 'bar' ],
                     [ :s, 'baz' ]
                   ],
                   RunSh::CommandParser.compact_command_field!([ [ :s, 'f' ],
                                                                 [ :s, 'o' ],
                                                                 [ :s, 'o' ],
                                                                 [ :other, 'bar' ],
                                                                 [ :s, 'baz' ]
                                                               ]))
    end

    def setup
      @parser = RunSh::CommandParser.new
    end

    def assert_command_parse(*expected_parsed_list, script_text, continue: false)
      assert_equal(expected_parsed_list, @parser.parse!(script_text.dup).to_a)
      assert_equal(continue, @parser.continue?)
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

    def test_parse_fragments
      assert_command_parse('foo', continue: true)
      assert_command_parse(' bar', continue: true)
      assert_command_parse(' ', continue: true)
      assert_command_parse('b', continue: true)
      assert_command_parse('a', continue: true)
      assert_command_parse('z', continue: true)
      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :s, 'bar' ] ],
                             [ [ :s, 'baz' ] ]
                           ],
                           "\n")
    end

    def test_parse_command_list
      assert_command_parse([ :cmd, [ [ :s, 'foo' ] ] ],
                           [ :cmd, [ [ :s, 'bar' ] ] ],
                           "foo;bar\n")

      assert_command_parse([ :cmd, [ [ :s, 'foo' ] ] ],
                           [ :cmd, [ [ :s, 'bar' ] ] ],
                           " foo ; bar ; \n")

      assert_command_parse([ :cmd, [ [ :s, 'foo' ] ] ],
                           "foo;\n")
    end

    def test_parse_escape_normal_char
      assert_command_parse([ :cmd, [ [ :q, 'f' ], [ :s, 'oo' ] ] ],
                           "\\foo\n")
      assert_command_parse([ :cmd, [ [ :s, 'f' ], [ :q, 'o'], [ :s, 'o' ] ] ],
                           "f\\oo\n")
      assert_command_parse([ :cmd, [ [ :s, 'fo' ], [ :q, 'o' ] ] ],
                           "fo\\o\n")
    end

    def test_parse_escape_special_char
      assert_command_parse([ :cmd, [ [ :s, 'foo' ], [ :q, ' ' ], [ :s, 'bar' ] ] ],
                           "foo\\ bar\n")
      assert_command_parse([ :cmd, [ [ :q, "\\" ] ] ],
                           "\\\\\n")
    end

    def test_parse_escape_continue
      assert_command_parse("\\", continue: true)
      assert_command_parse([ :cmd, [ [ :q, ' ' ], [ :s, 'foo' ] ] ],
                           " foo\n")

      assert_command_parse("foo\\\n", continue: true)
      assert_command_parse([ :cmd, [ [ :s, "foobar" ] ] ],
                           "bar\n")
    end

    def test_parse_single_quote
      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :q, 'bar' ] ]
                           ],
                           "foo 'bar'\n")

      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :s, 'abc' ], [ :q, 'def' ], [ :s, 'g' ] ]
                           ],
                           "foo abc'def'g\n")
    end

    def test_parse_single_quote_special_char
      assert_command_parse([ :cmd, [ [ :q, '"foo"' ] ] ],
                           %Q{'"foo"'\n})

      assert_command_parse([ :cmd, [ [ :q, "foo; bar\nbaz" ] ] ],
                           "'foo; bar\nbaz'\n")
    end

    def test_parse_single_quote_continue
      assert_command_parse("foo '\n", continue: true)
      assert_command_parse("echo HALO\n", continue: true)
      assert_command_parse([ :cmd, 
                             [ [ :s, 'foo' ] ],
                             [ [ :q, "\necho HALO\n" ] ]
                           ],
                           "'\n")
    end

    def test_parse_double_quote
      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :Q,
                                 [ :s, 'bar' ]
                               ]
                             ]
                           ],
                           %Q'foo "bar"\n')

      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :s, 'ab' ],
                               [ :Q,
                                 [ :s, 'cd' ]
                               ],
                               [ :s, 'ef' ]
                             ]
                           ],
                           %Q'foo ab"cd"ef\n')
    end

    def test_parse_double_quote_special_char
      assert_command_parse([ :cmd,
                             [ [ :Q,
                                 [ :s, "'foo'" ]
                               ]
                             ]
                           ],
                           %Q{"'foo'"\n})

      assert_command_parse([ :cmd,
                             [ [ :Q,
                                 [ :s, "foo; bar\nbaz" ]
                               ]
                             ]
                           ],
                           %Q'"foo; bar\nbaz"\n')
    end

    def test_parse_double_quote_escape
      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :Q,
                                 [ :s, '"Hello world."' ],
                               ]
                             ]
                           ],
                           %Q'foo "\\"Hello world.\\""\n')

      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :Q,
                                 [ :s, 'Hello world.' ],
                               ]
                             ]
                           ],
                           %Q'foo "Hello\\\n world."\n')
    end

    def test_parse_double_quote_continue
      assert_command_parse(%Q'foo "\n', continue: true)
      assert_command_parse("echo HALO\n", continue: true)
      assert_command_parse([ :cmd,
                             [ [ :s, 'foo' ] ],
                             [ [ :Q,
                                 [ :s, "\necho HALO\n" ]
                               ]
                             ]
                           ],
                           %Q'"\n')
    end
  end

  class CommandInterpreterTest < Test::Unit::TestCase
    def setup
      @interpreter = RunSh::CommandInterpreter.new
    end

    def assert_expand_command_field(expected_expansion_result, field_list)
      assert_equal(expected_expansion_result,
                   @interpreter.expand_command_field(field_list))
    end

    def test_expand_command_field
      assert_expand_command_field('foo',
                                  [ [ :s, 'foo' ] ])
      assert_expand_command_field(' ',
                                  [ [ :q, ' ' ] ])
      assert_expand_command_field('Hello world.',
                                  [ [ :Q, [ :s, 'Hello world.' ] ] ])
      assert_expand_command_field('foo abcdef',
                                  [ [ :s, 'foo' ],
                                    [ :q, ' ' ],
                                    [ :Q,
                                      [ :s, 'abc' ],
                                      [ :s, 'def' ]
                                    ]
                                  ])
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
