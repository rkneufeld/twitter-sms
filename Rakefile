require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rcov/rcovtask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "twitter-sms"
    s.summary = %Q{Twitter-SMS lets you send SMS updates to your phone}
    s.email = "neufelry@gmail.com"
    s.homepage = "http://github.com/neufelry/twitter-sms"
    s.description = "Twitter-SMS provides a persistent command line tool to send SMS updates to your mobile phone via a gmail account."
    s.authors = ["Ryan Neufeld"]
    s.executables = ["twitter-sms"]
    s.files = FileList["[A-Z]*.*", "{bin,generators,lib,test,spec}/**/*"]
    ['neufelry-twitter','tlsmail','rmail'].each {|g| s.add_dependency g }
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'twitter-sms'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

Rcov::RcovTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task :default => :rcov

task :config do
  config = YAML.load_file(ENV['HOME'] + '/.twitter-sms.conf')
  skip_by = 60 / config['config']['per_hour']
  puts "Please add the following to your cron jobs on your own or via 'crontab -e' "
  puts "*/#{skip_by} * * * * #{ENV['USER']} #{ENV['PWD']+'/twitter-sms.rb'}"
end

