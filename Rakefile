# -*- coding: utf-8 -*-

require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |task|
  if ((ENV.key? 'RUBY_DEBUG') && (! ENV['RUBY_DEBUG'].empty?)) then
    task.ruby_opts << '-d'
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
