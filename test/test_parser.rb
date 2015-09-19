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
