# -*- coding: utf-8 -*-

module RunSh
  module SyntaxStruct
    using Module.new{
      refine String do
        def accept(visitor)
          visitor.visit_s(self)
        end
      end
    }

    class CommandList
      def initialize(eoc: nil)
        @fields = []
        @eoc = eoc
      end

      attr_reader :fields
      attr_accessor :eoc

      def ==(other)
        if (other.is_a? CommandList) then
          @fields == other.fields && @eoc == other.eoc
        end
      end

      def empty?
        @fields.empty?
      end

      def add(field_list)
        @fields << field_list
        self
      end

      def strip!
        while (! @fields.empty? && @fields.last.empty?)
          @fields.pop
        end
        self
      end

      def accept(visitor)
        visitor.visit_cmd_list(self, @fields)
      end
    end

    class FieldList
      def initialize
        @values = []
      end

      attr_reader :values

      def ==(other)
        if (other.is_a? FieldList) then
          @values == other.values
        end
      end

      def empty?
        @values.empty?
      end

      def add(value)
        if ((value.is_a? String) &&
            (@values.length > 0) && (@values.last.is_a? String))
        then
          @values.last << value
        else
          @values << value
        end

        self
      end

      def accept(visitor)
        visitor.visit_field_list(self, @values)
      end
    end

    class QuotedString
      def initialize
        @string = ''
      end

      attr_reader :string

      def ==(other)
        if (other.is_a? QuotedString) then
          @string == other.string
        end
      end

      def add(string)
        @string << string
        self
      end

      def accept(visitor)
        visitor.visit_qs(self, @string)
      end
    end

    class DoubleQuotedList
      def initialize
        @values = []
      end

      attr_reader :values

      def ==(other)
        if (other.is_a? DoubleQuotedList) then
          @values == other.values
        end
      end

      def add(value)
        if ((value.is_a? String) &&
            (@values.length > 0) && (@values.last.is_a? String))
        then
          @values.last << value
        else
          @values << value
        end

        self
      end

      def accept(visitor)
        visitor.visit_qq_list(self, @values)
      end
    end

    class ParameterExansion
      def initialize(name: nil, separator: nil)
        @name = name
        @separator = separator
        @default_values = []
      end

      attr_accessor :name
      attr_accessor :separator
      attr_reader :default_values

      def ==(other)
        if (other.is_a? ParameterExansion) then
          @name == other.name &&
            @separator == other.separator &&
            @default_values == other.default_values
        end
      end

      def add(value)
        if ((value.is_a? String) &&
            (@default_values.length > 0) && (@default_values.last.is_a? String))
        then
          @default_values.last << value
        else
          @default_values << value
        end

        self
      end

      def accept(visitor)
        visitor.visit_param_expan(self)
      end

      def accept_default_values(visitor)
        unless (@default_values.empty?) then
          @default_values.map{|value| value.accept(visitor) }.join('')
        end
      end
    end

    class CommandListVisitor
      def initialize(context, cmd_intp)
        @c = context
        @i = cmd_intp
      end

      def visit_cmd_list(cmd_list, fields)
        fields.map{|field_list| field_list.accept(self) }
      end

      def visit_field_list(field_list, values)
        values.map{|value| value.accept(self) }.join('')
      end

      def visit_qs(qs, string)
        string
      end

      def visit_qq_list(qq_list, values)
        values.map{|value| value.accept(self) }.join('')
      end

      def visit_s(string)
        string
      end

      def visit_param_expan(parameter_expansion)
        case (parameter_expansion.name)
        when /\A#./
          plain_param_expan = ParameterExansion.new
          plain_param_expan.name = parameter_expansion.name[1..-1]
          value_string = plain_param_expan.accept(self)
          if (value_string) then
            value = value_string.length.to_s
          else
            value = '0'
          end
        else
          value = @c.get_var(parameter_expansion.name)
        end

        if (parameter_expansion.separator) then
          case (parameter_expansion.separator)
          when ':-'
            if (value.nil? || value.empty?) then
              value = parameter_expansion.accept_default_values(self)
            end
          when '-'
            if (value.nil?) then
              value = parameter_expansion.accept_default_values(self)
            end
          when ':='
            if (value.nil? || value.empty?) then
              value = parameter_expansion.accept_default_values(self)
              @c.put_var(parameter_expansion.name, value) if value
            end
          when '='
            if (value.nil?) then
              value = parameter_expansion.accept_default_values(self)
              @c.put_var(parameter_expansion.name, value) if value
            end
          when ':?'
            if (value.nil? || value.empty?) then
              if (msg = parameter_expansion.accept_default_values(self)) then
                raise "undefined parameter: #{parameter_expansion.name}: #{msg}"
              else
                raise "undefined parameter: #{parameter_expansion.name}"
              end
            end
          when '?'
            if (value.nil?) then
              if (msg = parameter_expansion.accept_default_values(self)) then
                raise "undefined parameter: #{parameter_expansion.name}: #{msg}"
              else
                raise "undefined parameter: #{parameter_expansion.name}"
              end
            end
          when ':+'
            if (! value.nil? && ! value.empty?) then
              value = parameter_expansion.accept_default_values(self)
            end
          when '+'
            if (! value.nil?) then
              value = parameter_expansion.accept_default_values(self)
            end
          when '%%'
            # not implemented.
          when '%'
            # not implemented.
          when '##'
            # not implemented.
          when '#'
            # not implemented.
          else
            raise "syntax error: invalid parameter expansion separator: #{@separator}"
          end
        end

        value || ''
      end
    end

    def expand(syntax_tree, context, cmd_intp)
      syntax_tree.accept(CommandListVisitor.new(context, cmd_intp))
    end
    module_function :expand
  end

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

    def parse_command
      cmd_list = CommandList.new

      field_list = FieldList.new
      cmd_list.add(field_list)

      each_token do |token|
        case (token.name)
        when :param
          param_expan = ParameterExansion.new
          param_expan.name = token.value[1..-1]
          field_list.add(param_expan)
        when :space
          unless (field_list.empty?) then
            field_list = FieldList.new
            cmd_list.add(field_list)
          end
        when :escape
          escaped_char = token.value[1..-1]
          if (escaped_char != "\n") then
            field_list.add(QuotedString.new.add(escaped_char))
          end
        when :quote
          field_list.add(parse_single_quote)
        when :qquote
          field_list.add(parse_double_quote)
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

      each_token do |token|
        case (token.name)
        when :qquote
          return qq_list
        when :param
          param_expan = ParameterExansion.new
          param_expan.name = token.value[1..-1]
          qq_list.add(param_expan)
        when :escape
          escaped_char = token.value[1..-1]
          if (escaped_char != "\n") then
            qq_list.add(escaped_char)
          end
        else
          qq_list.add(token.value)
        end
      end

      raise "syntax error: not terminated double-quoted string: #{qq_list.values}"
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
