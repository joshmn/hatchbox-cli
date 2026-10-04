# frozen_string_literal: true

module Hatchbox
  class Command
    include Hatchbox::Commands::Context
    include Hatchbox::Commands::Output
    include Hatchbox::Commands::Tracking

    APP_FLAGS = [
      ["-a", "--app APP", "app to run command against"],
      ["-r", "--remote REMOTE", "environment in .hatchbox to run command against"]
    ].freeze

    WAIT_FLAG = [nil, "--no-wait", "return once Hatchbox has queued it, without waiting for it to finish"].freeze
    JSON_FLAG = [nil, "--json", "output in json format"].freeze

    class << self
      attr_reader :meta

      def describe(name, summary:, usage: nil, help: nil, flags: [], examples: [], aliases: [], app: true, hidden: false, lenient: false)
        @meta = {
          name: name,
          summary: summary,
          usage: usage || name,
          help: help,
          flags: flags,
          examples: examples,
          aliases: aliases,
          app: app,
          hidden: hidden,
          lenient: lenient
        }
        Hatchbox::Registry.add(self)
      end

      def call(session:, args:)
        command = new(session: session, args: args)
        command.prepare
        command.call
      end
    end

    def initialize(session:, args:)
      @session = session
      @args = args
    end

    def prepare
      return unless meta[:app] == true

      wanted = positional_app
      @session = Hatchbox::Session.new(app_flag: wanted, remote_flag: session.remote_flag) if wanted && Hatchbox.blank?(session.app_flag)
      session.target
    end

    private

    attr_reader :session, :args

    def meta
      self.class.meta
    end

    def arguments
      @arguments ||= Hatchbox::ArgumentParser.new(flags: meta[:flags], lenient: meta[:lenient]).parse(args)
    end

    def options
      arguments.options
    end

    def positionals
      arguments.positionals
    end

    def passthru
      arguments.passthru
    end

    def positional_app
      nil
    end

    def none!
      usage_error("Unexpected argument: #{positionals.join(" ")}") if positionals.any?
    end

    def one_positional(what)
      usage_error("Must specify #{what}.") if positionals.empty?
      usage_error("Only one #{what} at a time, got #{positionals.join(" ")}.") if positionals.length > 1

      positionals.first
    end

    def usage_error(message)
      raise Hatchbox::Error, "Usage: hatchbox #{meta[:usage]}\n#{message}"
    end

    def confirm(expected:, lines:)
      ui.confirm(expected: expected, supplied: options[:confirm], lines: lines, prompt: prompt)
    end
  end
end
