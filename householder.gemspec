# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'householder/version'

Gem::Specification.new do |spec|
  spec.name          = "householder"
  spec.version       = Householder::VERSION
  spec.authors       = ["Steven Talcott Smith"]
  spec.email         = ["steve@aelogica.com"]
  spec.description   = %q{Give your vagrant a home.}
  spec.summary       = %q{This gem helps you take a Vagrant "box" style virtual machine definition and deploy it to a remote host server with a fixed IP address.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-nc"
end
