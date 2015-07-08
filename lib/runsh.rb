# -*- coding: utf-8 -*-

require 'runsh/version'

module RunSh
  class CommandParser
    def self.compact_command_field!(field_list)
      i = 0
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
            (?<eoc> \n | ; )
          )
        ) |
        (?<word> .* )
      )
    /x

    def parse_list!(script_text)
      frame = @stack.last
      cmd_list = frame[1]

      script_text.sub!(TOKEN_FETCH_PATTERN, '') or raise "failed to fetch a word of list: #{script_text}"

      if ($~[:word] && ! $~[:word].empty?) then
        if (cmd_list.empty?) then
          cmd_list << :cmd
          cmd_list << []
        end
        cmd_list.last.push([ :s, $~[:word] ])
      end

      if ($~[:space]) then
        unless (cmd_list.empty?) then
          cmd_list << []
        end
      end

      if ($~[:escape]) then
        raise 'not implemented escape character.'
      end

      if ($~[:eoc]) then
        unless (cmd_list.empty?) then
          while (cmd_list.last.empty?)
            cmd_list.pop
          end
        end
        unless (cmd_list.empty?) then
          for field_list in cmd_list
            self.class.compact_command_field!(field_list)
          end
          yield(cmd_list)
        end
        frame[1] = []
      end

      self
    end
    private :parse_list!

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
