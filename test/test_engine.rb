#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'runsh'
require 'test/unit'

module RunSh::Test
  class ScriptContextTest < Test::Unit::TestCase
    def setup
      @program_name = 'foo'
      @args = %w[ apple banana orange ]
      @pid = 1234
      @env = {
        'ENV1' => 'Alice',
        'ENV2' => 'Bob'
      }
      @context = RunSh::ScriptContext.new(pid: @pid, env: @env)
      @context.program_name = @program_name
      @context.args = @args
    end

    def test_program_name
      assert_equal(@program_name, @context.program_name)
      assert_equal(@program_name, @context.get_var('0'))
    end

    def test_args
      assert_equal(@args, @context.args)
      assert_equal(@args.length.to_s, @context.get_var('#'))
      @args.each_with_index do |expected_value, i|
        n = i + 1
        assert_equal(expected_value, @context.get_var(n.to_s), "num:#{n}")
      end
    end

    def test_pid
      assert_equal(@pid, @context.pid)
      assert_equal(@pid.to_s, @context.get_var('$'))
    end

    def test_command_status
      assert_equal(0, @context.command_status)
      assert_equal('0', @context.get_var('?'))

      @context.command_status = 1
      assert_equal(1, @context.command_status)
      assert_equal('1', @context.get_var('?'))
    end

    def test_shell_var
      @env.each do |name, value|
        assert_equal(value, @context.get_var(name), "name:#{name}")
      end
      assert_equal(@env.to_a, @context.each_var.to_a)

      assert_nil(@context.get_var('var1'))
      assert_nil(@env['var1'])

      @context.put_var('var1', 'Carol')

      env_vars = @env.to_a
      assert_equal('Carol', @context.get_var('var1'))
      assert_nil(@env['var1'])
      assert_equal(env_vars + [ [ 'var1', 'Carol' ] ], @context.each_var.to_a)

      @context.export('var1')

      env_vars << [ 'var1', 'Carol' ]
      assert_equal('Carol', @context.get_var('var1'))
      assert_equal('Carol', @env['var1'])
      assert_equal(env_vars, @env.to_a)
      assert_equal(env_vars, @context.each_var.to_a)

      @context.export('var2')

      env_vars << [ 'var2', '' ]
      assert_equal('', @context.get_var('var2'))
      assert_equal('', @env['var2'])
      assert_equal(env_vars, @env.to_a)
      assert_equal(env_vars, @context.each_var.to_a)
    end
  end
end

# Local Variables:
# indent-tabs-mode: nil
# End:
