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
        @args.length.to_s
      when '@', '*'
        @args.join(' ') unless @args.empty?
      when '?'
        @command_status.to_s
      when '-'
        nil                     # not implemented.
      when '$'
        @pid.to_s
      when '!'
        nil                     # not implemented.
      when '0'
        @program_name
      when /\A[1-9]\d*\z/
        @args[name.to_i - 1]
      when /\A[_A-Za-z][_A-Za-z0-9]*\z/
        if (@env.key? name) then
          @env[name]
        elsif (@var.key? name) then
          @var[name]
        end
      else
        raise "syntax error: invalid parameter name to get: #{name}"
      end
    end

    def put_var(name, value)
      case (name)
      when /\A[_A-Za-z][_A-Za-z0-9]*\z/
        if (@env.key? name) then
          @env[name] = value
        else
          @var[name] = value
        end
      else
        raise "syntax error: invalid parameter name to put: #{name}"
      end

      self
    end

    def unset_var(name)
      case (name)
      when /\A[_A-Za-z][_A-Za-z0-9]*\z/
        @var.delete(name)
        @env.delete(name)
      else
        raise "syntax error: invalid parameter name to put: #{name}"
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
        cmd_exec_list = SyntaxStruct.expand(cmd_list, @c, self)
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
