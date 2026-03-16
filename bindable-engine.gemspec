# frozen_string_literal: true

require_relative "lib/bindable_engine/version"

Gem::Specification.new do |spec|
  spec.name = "bindable-engine"
  spec.version = BindableEngine::VERSION
  spec.authors = ["Dick Dowdell"]
  spec.summary = "Biological component interface for Ruby — 6-method Bindables with MCP tool generation"
  spec.description = <<~DESC
    A minimal, zero-dependency implementation of the Bindable pattern: autonomous
    domain components with a uniform 6-method interface (create, read, update,
    delete, list, execute), immutable ContextRecords, thread-safe registry,
    automatic MCP tool generation, and cell-membrane governance via MessageModerator.
  DESC
  spec.homepage = "https://github.com/laquereric/bindable-engine"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["github_repo"] = "ssh://github.com/laquereric/bindable-engine"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE.txt", "README.md", "VERSION"]
  end

  spec.require_paths = ["lib"]

  # ZERO runtime dependencies — pure Ruby stdlib
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
