# -*- coding: utf-8 -*-

module RunSh
  class ScriptContext
    def initialize(pid: Process.pid, env: ENV)
      @program_name = File.basename($0)
      @args = []
      @pid = pid
      @command_status = 0
      @env = env
      @var = {}
      @IFS_src = nil
      @IFS_re = nil
    end

    attr_accessor :program_name
    attr_accessor :args
    attr_accessor :pid
    attr_accessor :command_status

    def get_var(name)
      case (name)
      when '#'
        return @args.length.to_s
      when '?'
        return @command_status.to_s
      when '-'
        return nil              # not implemented.
      when '$'
        return @pid.to_s
      when '!'
        return nil              # not implemented.
      when '0'
        return @program_name
      when /\A[1-9]\z/
        return @args[name.to_i - 1]
      end

      if (@env.key? name) then
        @env[name]
      elsif (@var.key? name) then
        @var[name]
      end
    end

    def put_var(name, value)
      if (@env.key? name) then
        @env[name] = value
      else
        @var[name] = value
      end
      self
    end

    def each_var
      return enum_for(:each_var) unless block_given?
      for name, value in @env
        yield(name, value)
      end
      for name, value in @var
        yield(name, value)
      end
      self
    end

    def export(name)
      value = @var.delete(name) || ''
      @env[name] = value
      self
    end

    def IFS_regexp
      ifs = get_var('IFS') || " \t\n"
      if (@IFS_src != ifs) then
        @IFS_re = Regexp.new(ifs.chars.map{|c| Regexp.quote(c) }.join('|'))
      end
      @IFS_re
    end
  end

  class CommandInterpreter
    def initialize(script_context)
      @c = script_context
    end

    def run(cmd_list)
      unless (cmd_list.empty?) then
        cmd_exec_list = cmd_list.to_cmd_exec_list(self, @c)
        system(*cmd_exec_list)
        $?.exitstatus
      end
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
