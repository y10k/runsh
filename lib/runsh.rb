# -*- coding: utf-8 -*-

require 'runsh/engine'
require 'runsh/parser'
require 'runsh/token'
require 'runsh/version'

module RunSh
  class Shell
    def initialize
      @c = ScriptContext.new
    end

    def run(*args)
      if (args.empty?) then
        input = STDIN
      else
        shell_script = args[0]
        input = File.open(shell_script, 'r')
      end

      ts = TokenScanner.new(input)
      cmd_p = CommandParser.new(ts.scan_token)
      cmd_i = CommandInterpreter.new(@c)

      exit_status = 0
      begin
        loop do
          print 'runsh$ ' if input.tty?
          cmd_list = cmd_p.parse_command or break
          exit_status = cmd_i.run(cmd_list) || exit_status
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
