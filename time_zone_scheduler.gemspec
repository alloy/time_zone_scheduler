# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'time_zone_scheduler'

Gem::Specification.new do |spec|
  spec.name          = "time_zone_scheduler"
  spec.version       = TimeZoneScheduler::VERSION
  spec.authors       = ["Eloy Durán"]
  spec.email         = ["eloy.de.enige@gmail.com"]

  spec.summary       = "A library that assists in scheduling events whilst taking time zones into account."
  spec.homepage      = "https://github.com/alloy/time_zone_scheduler"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "timecop", "~> 0.8.0"
end
