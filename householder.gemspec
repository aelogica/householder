# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'householder/version'

Gem::Specification.new do |spec|
  spec.name          = "householder"
  spec.version       = Householder::VERSION
  spec.authors       = ["Steven Talcott Smith", "Nestor G Pestelos Jr"]
  spec.email         = ["steve@aelogica.com", "nestor@aelogica.com"]
  spec.description   = %q{Give your VirtualBox a home.}
  spec.summary       = %q{This gem helps you take a Vagrant "box" style virtual machine definition and deploy it to a remote host server with a fixed IP address.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "ssh-forever", "~> 0.2.3"
  spec.add_dependency "net-ssh", "~> 2.8.0"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "highline", "~> 1.6.20"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "cucumber"
  spec.add_development_dependency "aruba"
  spec.add_development_dependency "dotenv"
end
