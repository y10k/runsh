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
        when :cmd_sep, :cmd_term
          cmd_list.eoc = token_value
          return cmd_list.strip!
        else
          field_list.add(token_value)
        end
      end

      cmd_list.strip!
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
