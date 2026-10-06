# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"
require "pathname"
require "socket"
require "shellwords"
require "tmpdir"
require "fileutils"
require "time"
require "io/console"
require "open3"
require "rbconfig"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

module Hatchbox
  class Error < StandardError; end
  class UsageError < Error; end

  NAME = /\A[A-Za-z0-9_-]+\z/.freeze

  class << self
    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def color?(io = $stdout)
      return false if ENV["NO_COLOR"]

      io.tty?
    end

    def run(argv, env: {})
      started = system(env, *argv)
      raise Error, "#{argv.first} is required and is not installed." if started.nil?

      exit_code($?)
    end

    def exit_code(status)
      return status.exitstatus if status.exitstatus

      128 + status.termsig.to_i
    end

    def parallel(jobs)
      threads = jobs.map do |key, job|
        thread = Thread.new do
          Thread.current.report_on_exception = false
          job.call
        end
        [key, thread]
      end
      threads.to_h { |key, thread| [key, thread.value] }
    end

    def ssh_options
      Shellwords.split(ENV["HATCHBOX_SSH_OPTIONS"].to_s)
    end

    def tilde(path)
      path.sub(/\A#{Regexp.escape(Dir.home)}/, "~")
    end

    def platform
      "hatchbox/#{VERSION} #{RbConfig::CONFIG["host_os"]}-#{RbConfig::CONFIG["host_cpu"]} ruby-#{RUBY_VERSION}"
    end

    def slug_id(slug)
      slug.to_s[/\A[0-9]+/]
    end

    def slug_name(slug)
      slug.to_s.sub(/\A[0-9]+-?/, "")
    end

    def check_name!(name)
      return if name =~ NAME

      raise Error, "#{name} is not a name Hatchbox takes. Use letters, numbers, hyphens and underscores."
    end
  end
end

loader.eager_load_dir(File.join(__dir__, "hatchbox", "commands"))
