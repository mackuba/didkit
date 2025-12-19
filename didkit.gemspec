# frozen_string_literal: true

require_relative "lib/didkit/version"

Gem::Specification.new do |spec|
  spec.name = "didkit"
  spec.version = DIDKit::VERSION
  spec.authors = ["Kuba Suder"]
  spec.email = ["jakub.suder@gmail.com"]

  spec.summary = "A library for handling Distributed ID (DID) identifiers used in Bluesky AT Protocol"
  # spec.description = "Write a longer description or delete this line."
  spec.homepage = "https://github.com/mackuba/didkit"

  spec.license = "Zlib"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri"   => "https://github.com/mackuba/didkit/issues",
    "changelog_uri"     => "https://github.com/mackuba/didkit/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/mackuba/didkit",
  }

  spec.files = Dir.chdir(__dir__) do
    Dir['*.md'] + Dir['*.txt'] + Dir['lib/**/*'] + Dir['sig/**/*']
  end

  spec.require_paths = ["lib"]

  spec.add_dependency 'uri', '>= 0.11.0'
end
