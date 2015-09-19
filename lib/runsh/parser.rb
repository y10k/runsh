# -*- coding: utf-8 -*-

require 'runsh/syntax'

module RunSh
  class CommandParser
    include SyntaxStruct

    def initialize(token_src)
      @token_src = token_src
      @token_push_back_list = []
    end

    def each_token
      begin
        loop do
          if (@token_push_back_list.empty?) then
            yield(@token_src.next)
          else
            yield(@token_push_back_list.shift)
          end
        end
      rescue StopIteration
        # end of loop
      end
    end
    private :each_token

    def push_back(token)
      @token_push_back_list.push(token)
      nil
    end
    private :push_back

    def make_escape(token_value)
      escaped_char = token_value[1..-1]
      if (escaped_char != "\n") then
        yield(escaped_char)
      end
    end
    private :make_escape

    def make_single_token_parameter_expansion(token_value)
      ParameterExansion.new(name: token_value[1..-1])
    end
    private :make_single_token_parameter_expansion

    def make_param(add_callback)
      each_token do |token|
        case (token.name)
        when :param
          add_callback.call(make_single_token_parameter_expansion(token.value))
        when :param_begin
          add_callback.call(parse_parameter_expansion)
        else
          yield(token)
        end
      end
    end
    private :make_param

    def make_param_quote(add_callback)
      make_param(add_callback) do |token|
        case (token.name)
        when :escape
          make_escape(token.value) {|escaped_char|
            add_callback.call(QuotedString.new.add(escaped_char))
          }
        when :quote
          add_callback.call(parse_single_quote)
        when :qquote
          add_callback.call(parse_double_quote)
        else
          yield(token)
        end
      end
    end
    private :make_param_quote

    def parse_command
      cmd_list = CommandList.new

      field_list = FieldList.new
      cmd_list.add(field_list)

      make_param_quote(proc{|node| field_list.add(node) }) do |token|
        case (token.name)
        when :space
          unless (field_list.empty?) then
            field_list = FieldList.new
            cmd_list.add(field_list)
          end
        when :cmd_sep, :cmd_term
          cmd_list.eoc = token.value
          return cmd_list.strip!
        when :word
          if (token.value =~ /\A#/) then
            parse_comment
          else
            field_list.add(token.value)
          end
        else
          field_list.add(token.value)
        end
      end

      cmd_list.strip!
      cmd_list unless cmd_list.empty?
    end

    def parse_comment
      each_token do |token|
        case (token.name)
        when :cmd_term
          push_back(token)
          return
        else
          # skip comment
        end
      end
    end

    def parse_single_quote
      qs = QuotedString.new

      each_token do |token|
        case (token.name)
        when :quote
          return qs
        else
          qs.add(token.value)
        end
      end

      raise "syntax error: not terminated single-quoted string: #{qs.string}"
    end

    def parse_double_quote
      qq_list = DoubleQuotedList.new

      make_param(proc{|node| qq_list.add(node) }) do |token|
        case (token.name)
        when :qquote
          return qq_list
        when :escape
          make_escape(token.value) {|escaped_char|
            qq_list.add(escaped_char)
          }
        else
          qq_list.add(token.value)
        end
      end

      raise "syntax error: not terminated double-quoted string: #{qq_list.values}"
    end

    def parse_parameter_expansion
      param_expan = ParameterExansion.new
      param_expan.name = ''

      each_token do |token|
        case (token.name)
        when :group_end
          return param_expan
        else
          param_expan.name << token.value
          if (param_expan.name =~ / ^ (?<name> .+? ) (?<separator> :?[-=?+] | %%? | \#\#? ) /mx) then
            param_expan.name = $~[:name]
            param_expan.separator = $~[:separator]
            if ($' && ! $'.empty?) then
              param_expan.add($')
            end
            return parse_parameter_expansion_default(param_expan)
          end
        end
      end

      raise "syntax error: not terminated parameter expansion: #{param_expan.name}"
    end

    def parse_parameter_expansion_default(param_expan)
      make_param_quote(proc{|node| param_expan.add(node) }) do |token|
        case (token.name)
        when :group_end
          return param_expan
        else
          param_expan.add(token.value)
        end
      end

      raise "syntax error: not terminated parameter expansion: #{param_expan.name}"
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
