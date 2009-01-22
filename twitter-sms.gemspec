# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{twitter-sms}
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ryan Neufeld"]
  s.date = %q{2009-01-21}
  s.description = %q{Twitter-SMS provides a persistent command line tool to send SMS updates to your mobile phone via a gmail account.}
  s.email = %q{neufelry@gmail.com}
  s.files = ["VERSION.yml", "bin/twitter-sms", "lib/twitter_sms.rb", "test/test_helper.rb", "test/twitter_sms_test.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/neufelry/twitter-sms}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Twitter-SMS lets you send SMS updates to your phone}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end