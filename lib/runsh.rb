# -*- coding: utf-8 -*-

require 'runsh/version'

module RunSh
  class CommandParser
    def self.compact_command_field!(field_list, offset: 0)
      i = offset
      while (i < field_list.length - 1)
        if ((field_list[i][0] == :s) && (field_list[i + 1][0] == :s)) then
          field_list[i][1] << field_list[i + 1][1]
          field_list.delete_at(i + 1)
        else
          i += 1
        end
      end

      field_list
    end

    def initialize
      root_frame = [ :parse_list!, [] ]
      @stack = [ root_frame ]
    end

    TOKEN_FETCH_PATTERN = /
      ^(?:
        (?:
          (?<word> .*? )
          (?:
            (?<space> [ \t]+ ) |
            (?<escape> \\ ) |
            (?<quote> ' ) |
            (?<qquote> " ) |
            (?<eoc> \n | ; )
          )
        ) |
        (?<word> .* )
      )
    /x

    def cmd_list_init!(cmd_list)
      if (cmd_list.empty?) then
        cmd_list << :cmd
        cmd_list << []
      end
    end
    private :cmd_list_init!

    def cmd_field_add!(cmd_list)
      unless (cmd_list.empty?) then
        cmd_list << []
      end
    end
    private :cmd_field_add!

    def cmd_field_compact!(cmd_list)
      unless (cmd_list.empty?) then
        while (cmd_list.last.empty?)
          cmd_list.pop
        end
      end
      unless (cmd_list.empty?) then
        for field_list in cmd_list
          self.class.compact_command_field!(field_list)
        end
      end
    end
    private :cmd_field_compact!

    def parse_list!(script_text)
      frame = @stack.last
      cmd_list = frame[1]

      script_text.sub!(TOKEN_FETCH_PATTERN, '') or raise "failed to fetch a word of list: #{script_text}"

      if ($~[:word] && ! $~[:word].empty?) then
        cmd_list_init!(cmd_list)
        cmd_list.last.push([ :s, $~[:word] ])
      end

      if ($~[:space]) then
        cmd_field_add!(cmd_list)
      elsif ($~[:escape]) then
        cmd_list_init!(cmd_list)
        field_list = cmd_list.last
        @stack.push([ :parse_escape!, field_list ])
      elsif ($~[:quote]) then
        cmd_list_init!(cmd_list)
        q_str = ''
        cmd_list.last.push([ :q, q_str ])
        @stack.push([ :parse_single_quote!, q_str ])
      elsif ($~[:qquote]) then
        cmd_list_init!(cmd_list)
        qq_list = [ :Q ]
        cmd_list.last.push(qq_list)
        @stack.push([ :parse_double_quote!, qq_list ])
      elsif ($~[:eoc]) then
        cmd_field_compact!(cmd_list)
        yield(cmd_list) unless cmd_list.empty?
        frame[1] = []
      end
    end
    private :parse_list!

    def parse_escape!(script_text)
      script_text.sub!(/^./m, '') or raise 'unexpected empty script text.'
      escaped_char = $&

      if (escaped_char != "\n") then
        frame = @stack.last
        field_list = frame[1]
        field_list.push([ :s, escaped_char ])
      end

      @stack.pop
    end
    private :parse_escape!

    def parse_single_quote!(script_text)
      script_text.sub!(/^.*?'|^.+/m, '') or raise 'unexpected empty script text'
      quoted_string = $&

      frame = @stack.last
      if (quoted_string[-1] == "'") then
        frame[1] << quoted_string.chop!
        @stack.pop
      else
        frame[1] << quoted_string
      end
    end
    private :parse_single_quote!

    QQUOTE_FETCH_PATTERN = /
      ^(?:
        (?:
          (?<word> .*? )
          (?:
            (?<escape> \\ ) |
            (?<qquote> " )
          )
        ) |
        (?<word> .+ )
      )
    /mx

    def parse_double_quote!(script_text)
      frame = @stack.last
      qq_list = frame[1]

      script_text.sub!(QQUOTE_FETCH_PATTERN, '') or raise "failed to fetch a double quoted string: #{script_text}"

      if ($~[:word]) then
        qq_list << [ :s, $~[:word] ]
      end

      if ($~[:escape]) then
        @stack.push([ :parse_escape!, qq_list ])
      elsif ($~[:qquote]) then
        self.class.compact_command_field!(qq_list, offset: 1)
        @stack.pop
      end
    end
    private :parse_double_quote!

    def parse!(script_text, &block)
      return enum_for(:parse!, script_text) unless block_given?

      until (script_text.empty?)
        frame = @stack.last
        send(frame[0], script_text, &block)
      end

      self
    end
  end

  class Engine
    def initialize
      @command_parser = CommandParser.new
    end
  end

  class Shell
    def initialize
      @engine = Engine.new
    end

    def run(*args)
      if (args.empty?) then
        input = STDIN
      else
        shell_script = args[0]
        input = File.open(shell_script, 'r')
      end

      exit_status = 0
      begin
        loop do
          print 'runsh$ ' if input.tty?
          line = input.gets or break
          exit_status = @engine.put_line(line)
        end
      ensure
        input.close
      end

      exit(exit_status)
    end
  end
end

if ($0 == __FILE__) then
  shell = RunSh::Shell.new
  shell.run(*ARGV)
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
