# -*- coding: utf-8 -*-

require 'runsh'

module RunSh
  module SyntaxStruct
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

      def add(field_list)
        @fields << field_list
        self
      end

      def strip!
        while (! @fields.empty? && @fields.last.values.empty?)
          @fields.pop
        end
        self
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

      def add(value)
        @values << value
        self
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
    end
  end

  class CommandParser
    include SyntaxStruct

    def initialize(token_src)
      @token_src = token_src
    end

    def each_token
      begin
        loop do
          token_name, token_value = @token_src.next
          yield(token_name, token_value)
        end
      rescue StopIteration
        # end of loop
      end
    end
    private :each_token

    def parse_command
      cmd_list = CommandList.new

      field_list = FieldList.new
      cmd_list.add(field_list)

      each_token do |token_name, token_value|
        case (token_name)
        when :space
          unless (field_list.values.empty?) then
            field_list = FieldList.new
            cmd_list.add(field_list)
          end
        when :escape
          escaped_char = token_value[1..-1]
          if (escaped_char != "\n") then
            field_list.add(QuotedString.new.add(escaped_char))
          end
        when :quote
          field_list.add(parse_single_quote)
        when :qquote
          field_list.add(parse_double_quote)
        when :cmd_sep, :cmd_term
          cmd_list.eoc = token_value
          return cmd_list.strip!
        else
          field_list.add(token_value)
        end
      end

      cmd_list.strip!
    end

    def parse_single_quote
      qs = QuotedString.new

      each_token do |token_name, token_value|
        case (token_name)
        when :quote
          return qs
        else
          qs.add(token_value)
        end
      end

      raise "syntax error: not terminated single-quoted string: #{qs.string}"
    end

    def parse_double_quote
      qq_list = DoubleQuotedList.new

      each_token do |token_name, token_value|
        case (token_name)
        when :qquote
          return qq_list
        when :escape
          escaped_char = token_value[1..-1]
          if (escaped_char != "\n") then
            qq_list.add(escaped_char)
          end
        else
          qq_list.add(token_value)
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
