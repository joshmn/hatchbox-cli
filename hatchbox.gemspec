# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "hatchbox/version"

Gem::Specification.new do |spec|
  spec.name = "hatchbox"
  spec.version = Hatchbox::VERSION
  spec.authors = ["Josh"]
  spec.email = ["git@josh.mn"]

  spec.summary = "A command line for Hatchbox."
  spec.description = "Manage Hatchbox apps, processes, config vars, domains, databases, backups, servers and firewalls from the terminal, with logs, run and psql over SSH."
  spec.homepage = "https://github.com/joshdotmn/hatchbox"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/joshdotmn/hatchbox"
  spec.metadata["changelog_uri"] = "https://github.com/joshdotmn/hatchbox/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?("bin/", "Gemfile", ".gitignore", ".github/")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency("zeitwerk", "~> 2.6")
end
