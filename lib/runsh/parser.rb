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
        @values << value
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
    end

    def build_command_list(cmd_list, context, cmd_intp)
      cmd_list.accept(CommandListVisitor.new(context, cmd_intp))
    end
    module_function :build_command_list
  end

  class CommandParser
    include SyntaxStruct

    def initialize(token_src)
      @token_src = token_src
      @token_push_back_list = []
      @cmd_nest = 0
    end

    def parsing_command?
      @cmd_nest >= 1
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
      @cmd_nest += 1
      begin
        cmd_list = CommandList.new

        field_list = FieldList.new
        cmd_list.add(field_list)

        each_token do |token|
          case (token.name)
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
      ensure
        @cmd_nest -= 1
      end
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
