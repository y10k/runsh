# -*- coding: utf-8 -*-

module RunSh
  module SyntaxStruct
    using Module.new{
      refine String do
        def accept(visitor)
          visitor.visit_s(self)
        end
      end

      refine Array do
        def add_syntax_struct(value)
          if ((value.is_a? String) &&
              (self.length > 0) && (self.last.is_a? String))
          then
            self.last << value
          else
            self << value
          end

          self
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
        visitor.visit_cmd_list(self)
      end

      def new
        self.class.new(eoc: @eoc)
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
        @values.add_syntax_struct(value)
        self
      end

      def accept(visitor)
        visitor.visit_field_list(self)
      end

      def new
        self.class.new
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
        visitor.visit_qs(self)
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
        @values.add_syntax_struct(value)
        self
      end

      def accept(visitor)
        visitor.visit_qq_list(self)
      end

      def new
	self.class.new
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
        @default_values.add_syntax_struct(value)
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

    class ReplaceHolder
      def initialize
        @values = []
      end

      attr_reader :values

      def ==(other)
        if (other.is_a? ReplaceHolder) then
          @values == other.values
        end
      end

      def add(value)
        @values.add_syntax_struct(value)
        self
      end

      def accept(visitor)
        visitor.visit_replace_holder(self)
      end
    end

    class Visitor
      def initialize(context, cmd_intp)
        @c = context
        @i = cmd_intp
      end
    end

    class StringLengthVisitor < Visitor
      def initialize(context, cmd_intp)
        super
        @len = 0
      end

      def to_i
        @len
      end

      def visit_s(string)
        @len += string.length
      end

      def visit_qs(qs)
        @len += qs.string.length
      end

      def visit_qq_list(qq_list)
        for value in qq_list.values
          value.accept(self)
        end

        @len
      end

      def visit_replace_holder(replace_holder)
        for value in replace_holder.values
          value.accept(self)
        end

        @len
      end

      def visit_field_list(field_list)
        for value in field_list.values
          value.accept(self)
        end

        @len
      end
    end

    class ToStringVisitor < Visitor
      def initialize(context, cmd_intp)
        super
        @s = ''
      end

      def to_s
        @s
      end

      def visit_s(string)
        @s << string
      end

      def visit_qs(qs)
        @s << qs.string
      end

      def visit_qq_list(qq_list)
        for value in qq_list.values
          value.accept(self)
        end

        @s
      end

      def visit_replace_holder(replace_holder)
        for value in replace_holder.values
          value.accept(self)
        end

        @s
      end

      def visit_field_list(field_list)
        for value in field_list.values
          value.accept(self)
        end

        @s
      end
    end

    class CollectVisitor < Visitor
      def initialize(context, cmd_intp, collection)
        super(context, cmd_intp)
        @collection = collection
      end

      def visit_s(string)
        @collection.add(string)
        nil
      end

      def visit_qs(qs)
        @collection.add(qs)
        nil
      end

      def visit_qq_list(qq_list)
        new_qq_list = qq_list.new
        collect = CollectVisitor.new(@c, @i, new_qq_list)
        for value in qq_list.values
          value.accept(collect)
        end
        @collection.add(new_qq_list)

        nil
      end

      def visit_param_expan(parameter_expansion)
        case (parameter_expansion.name)
        when /\A#./
          plain_param_expan = ParameterExansion.new
          plain_param_expan.name = parameter_expansion.name[1..-1]
          len = plain_param_expan.accept(ReplaceVisitor.new(@c, @i)).accept(StringLengthVisitor.new(@c, @i))
          @collection.add(len.to_s)
        else
          expand_value = @c.get_var(parameter_expansion.name)

          unless (parameter_expansion.separator) then
            if (expand_value) then
              @collection.add(expand_value)
            end
          else
            case (parameter_expansion.separator)
            when ':-'
              if (expand_value.nil? || expand_value.empty?) then
                for value in parameter_expansion.default_values
                  value.accept(self)
                end
              else
                @collection.add(expand_value)
              end
            when '-'
              if (expand_value.nil?) then
                for value in parameter_expansion.default_values
                  value.accept(self)
                end
              else
                @collection.add(expand_value)
              end
            when ':='
              if (expand_value.nil? || expand_value.empty?) then
                expand_value = parameter_expansion.default_values.inject(ToStringVisitor.new(@c, @i)) {|visitor, value|
                  value.accept(visitor)
                  visitor
                }.to_s
                @c.put_var(parameter_expansion.name, expand_value)
              end
              @collection.add(expand_value)
            when '='
              if (expand_value.nil?) then
                expand_value = parameter_expansion.default_values.inject(ToStringVisitor.new(@c, @i)) {|visitor, value|
                  value.accept(visitor)
                  visitor
                }.to_s
                @c.put_var(parameter_expansion.name, expand_value)
              end
              @collection.add(expand_value)
            when ':?'
              if (expand_value.nil? || expand_value.empty?) then
                msg = parameter_expansion.default_values.inject(ToStringVisitor.new(@c, @i)) {|visitor, value|
                  value.accept(visitor)
                  visitor
                }.to_s
                if (msg.empty?) then
                  raise "undefined parameter: #{parameter_expansion.name}"
                else
                  raise "undefined parameter: #{parameter_expansion.name}: #{msg}"
                end
              else
                @collection.add(expand_value)
              end
            when '?'
              if (expand_value.nil?) then
                msg = parameter_expansion.default_values.inject(ToStringVisitor.new(@c, @i)) {|visitor, value|
                  value.accept(visitor)
                  visitor
                }.to_s
                if (msg.empty?) then
                  raise "undefined parameter: #{parameter_expansion.name}"
                else
                  raise "undefined parameter: #{parameter_expansion.name}: #{msg}"
                end
              else
                @collection.add(expand_value)
              end
            when ':+'
              unless (expand_value.nil? || expand_value.empty?) then
                for value in parameter_expansion.default_values
                  value.accept(self)
                end
              end
            when '+'
              unless (expand_value.nil?) then
                for value in parameter_expansion.default_values
                  value.accept(self)
                end
              end
            when '%%'
              # not impelmented
            when '%'
              # not impelmented
            when '##'
              # not impelmented
            when '#'
              # not impelmented
            else
              raise "syntax error: invalid parameter expansion separator: #{parameter_expansion.separator}"
            end
          end
        end

        nil
      end
    end

    class ReplaceVisitor < Visitor
      def visit_cmd_list(cmd_list)
        new_cmd_list = cmd_list.new
        for field_list in cmd_list.fields
          new_cmd_list.add(field_list.accept(self))
        end

        new_cmd_list
      end

      def visit_field_list(field_list)
        new_field_list = field_list.new
        for value in field_list.values
          new_field_list.add(value.accept(self))
        end

        new_field_list
      end

      def visit_param_expan(parameter_expansion)
        replace_holder = ReplaceHolder.new
        collect = CollectVisitor.new(@c, @i, replace_holder)
        parameter_expansion.accept(collect)

        replace_holder
      end

      def visit_qq_list(qq_list)
        new_qq_list = qq_list.new
        collect = CollectVisitor.new(@c, @i, new_qq_list)
        for value in qq_list.values
          value.accept(collect)
        end

        new_qq_list
      end

      def visit_qs(qs)
        qs
      end

      def visit_s(string)
        string
      end
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
