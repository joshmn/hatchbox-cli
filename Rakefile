# frozen_string_literal: true

require "bundler/gem_tasks"

desc "load every command and render its help"
task :smoke do
  require_relative "lib/hatchbox"
  require "stringio"

  ENV["HATCHBOX_NO_PLUGINS"] = "1"
  failed = []
  ([["--version"], ["help"], ["commands"]] + Hatchbox::Registry.commands.map { |klass| ["help", klass.meta[:name]] }).each do |argv|
    out = StringIO.new
    $stdout = out
    code = begin
      Hatchbox::Cli.start(argv)
    ensure
      $stdout = STDOUT
    end
    failed << argv.join(" ") if code != 0 || out.string.empty?
  end
  abort("these failed: #{failed.join(", ")}") if failed.any?
  puts("#{Hatchbox::Registry.commands.length} commands load and render help")
end

task(default: [:smoke, :build])
