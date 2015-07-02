# -*- coding: utf-8 -*-

require 'runsh/version'

module RunSh
  SPECIAL_SEPARATORS = %w[ ; ]

  TOKEN_FETCH_PATTERN = /
    (?<word> .*? )
    (?:
      (?<newline>
        \n
      ) |
      (?<space>
        [\ \t]+
      ) |
      (?<special>
        #{SPECIAL_SEPARATORS.map{|s| Regexp.quote(s) }.join('|')}
      )
    ) |
    (?<word> .* )
  /mx

  def scan_token(source_text)
    token_list = []

    source_text.scan(TOKEN_FETCH_PATTERN) do
      unless ($~[:word].empty?) then
        token_list.push([ :word, $~[:word] ])
      end
      for token_type in [ :special, :space, :newline ]
        if ($~[token_type]) then
          token_list.push([ token_type, $~[token_type] ])
        end
      end
    end

    token_list
  end
  module_function :scan_token

  class CommandParser
    def scan_line(token_list)
      return enum_for(:scan_line, token_list) unless block_given?

      cmd = [ :run ]
      while (token = token_list.shift)
        case (token[0])
        when :word
          cmd << token[1]
        when :sep
          case (token[1])
          when ';', "\n"
            yield(cmd)
            cmd = [ :run ]
          when /^[\ \t]+$/
            # skipped
          else
            cmd << token[1]
          end
        else
          raise "unknown token: #{token.join(', ')}"
        end
      end

      if (cmd.length > 1) then
        yield(cmd)
      end

      self
    end
  end

  class Engine
    def initialize
      @command_parser = CommandParser.new
    end

    def put_line(line)
      token_list = RunSh.scan_token(line)
      @command_parser.scan_line(token_list) do |cmd_type, *cmd_list|
        case (cmd_type)
        when :run
          system(*cmd_list)
        else
          raise "unknown command type: #{cmd_type}"
        end
      end

      $?.exitstatus
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
