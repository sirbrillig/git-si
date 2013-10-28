# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'git/si/version'

Gem::Specification.new do |spec|
  spec.name          = "git-si"
  spec.version       = Git::Si::VERSION
  spec.authors       = ["Payton Swick"]
  spec.email         = ["payton@foolord.com"]
  spec.description   = %q{Git Svn Interface: a simple git extention to use git locally with a remote svn repo.}
  spec.summary       = %q{It's like a simple version of git-svn which doesn't keep track of history locally.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "thor"
  spec.add_development_dependency "pager"

  spec.add_runtime_dependency "thor"
  spec.add_runtime_dependency "pager"
end
