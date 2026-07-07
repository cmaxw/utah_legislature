# frozen_string_literal: true

require_relative "lib/utah_legislature/version"

Gem::Specification.new do |spec|
  spec.name = "utah_legislature"
  spec.version = UtahLegislature::VERSION
  spec.authors = ["Charles Max Wood"]
  spec.email = ["chuck@topenddevs.com"]

  spec.summary = "Ruby client for the Utah State Legislature API, with bill-text parsing and chunking."
  spec.description = <<~DESC
    A dependency-light Ruby client for the Utah State Legislature's public API
    (glen.le.utah.gov): legislators, committees, bills, actions, and bill-version
    text. Includes an XML parser for the state's <leg> bill schema and a chunker
    that splits bill text into citation-labeled passages for search/RAG. No Rails
    dependency — returns plain value objects you map onto your own models.
  DESC
  spec.homepage = "https://github.com/cmaxw/utah_legislature"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0"
  spec.add_dependency "nokogiri", ">= 1.13"
end
