# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "activerecord/cte/version"

Gem::Specification.new do |spec|
  spec.name          = "activerecord-cte"
  spec.version       = Activerecord::Cte::VERSION
  spec.authors       = ["Vlado Cingel"]
  spec.email         = ["vladocingel@gmail.com"]

  spec.summary       = "Write a short summary, because RubyGems requires one."
  spec.description   = " Write a longer description or delete this line."
  spec.homepage      = "https://github.com/vlado/activerecord-cte"
  spec.license       = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/vlado/activerecord-cte"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0.1"
  spec.add_development_dependency "rubocop", "~> 0.80.1"
  spec.add_development_dependency "rubocop-performance", "~> 1.5.2"
  spec.add_development_dependency "sqlite3"
end
