$:.push File.expand_path("../lib", __FILE__)
require 'textile/version'

Gem::Specification.new do |s|
  s.name        = 'textile'
  s.version     = Textile::VERSION.dup
  s.license     = "MIT"
  s.summary     = "Recursive-descent style Textile parser"
  s.description = "Recursive-descent style Textile parser"
  s.authors     = ["Liam P. White"] 
  s.email       = 'example@example.com'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
end
