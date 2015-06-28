# -*- coding: utf-8 -*-

require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new do |task|
  if ((ENV.key? 'RUBY_DEBUG') && (! ENV['RUBY_DEBUG'].empty?)) then
    task.ruby_opts << '-d'
  end
end

desc 'run interactive RunSh.'
task :run do
  sh *%w[ bundle exec ruby lib/runsh.rb ]
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
