# -*- coding: utf-8 -*-

require 'runsh/parser'
require 'runsh/token'
require 'runsh/version'

module RunSh
  class CommandInterpreter
    def expand_command_field(field_list)
      field_list.map{|token|
        case (token[0])
        when :s, :q
          token[1]
        when :Q
          expand_command_field(token[1..-1])
        else
          raise "unknown token: #{token[0]}"
        end
      }.join('')
    end

    def run(cmd_list)
      cmd_type, *cmd_args = cmd_list
      case (cmd_type)
      when :cmd
        system(*cmd_args.map{|field_list|
                 expand_command_field(field_list)
               })
        $?.exitstatus
      else
        raise NotImplementedError, "unknown command type: #{cmd_type}"
      end
    end
  end

  class Shell
    def initialize
      @cmd_parser = CommandParser.new
      @cmd_intp = CommandInterpreter.new
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
          if (input.tty?) then
            if (@cmd_parser.continue?) then
              print '> '
            else
              print 'runsh$ '
            end
          end

          line = input.gets or break
          line << "\n" if (line[-1] != "\n")
          @cmd_parser.parse!(line) do |cmd_list|
            exit_status = @cmd_intp.run(cmd_list)
          end
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
