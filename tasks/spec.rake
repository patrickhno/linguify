require 'rake'
require 'rspec/core/rake_task'

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  #t.pattern = FileList['./spec/**/*_spec.rb']
end

#task :spec => [:compile]
#task :default => :spec
