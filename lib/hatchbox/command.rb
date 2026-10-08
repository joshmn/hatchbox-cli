# frozen_string_literal: true

module Hatchbox
  class Command
    include Hatchbox::Commands::Context
    include Hatchbox::Commands::Tracking

    APP_FLAGS = [
      ["-a", "--app APP", "app to run command against"],
      ["-r", "--remote REMOTE", "remote saved for this repo in ~/.hatchbox to run command against"]
    ].freeze

    WAIT_FLAG = [nil, "--no-wait", "return once Hatchbox has queued it, without waiting for it to finish"].freeze
    JSON_FLAG = [nil, "--json", "output in json format"].freeze
    SERVER_FLAG = ["-s", "--server SERVER", "the server, by name, id or role"].freeze
    CONFIRM_APP_FLAG = [nil, "--confirm APP", "the app's name, to skip the prompt"].freeze

    class << self
      attr_reader :meta

      def describe(name, summary:, usage: nil, help: nil, args: {}, flags: [], examples: [], aliases: [], app: true, ssh: nil, lenient: false)
        switches = flags.map { |spec| Hatchbox::Flag.new(spec) }
        clashing = switches.select { |flag| flag.global? }
        raise Hatchbox::Error, "#{name} can't define #{clashing.map { |flag| flag.label.strip }.join(" or ")}, since hatchbox reads those itself." if clashing.any?

        @meta = {
          name: name,
          summary: summary,
          usage: usage || ([name] + args.values).join(" "),
          help: help,
          args: args.map { |key, text| Hatchbox::Arguments::Spec.new(name: key, text: text) },
          flags: switches,
          examples: examples,
          aliases: aliases,
          app: app,
          ssh: ssh,
          lenient: lenient
        }
        Hatchbox::Registry.add(self)
      end

      def call(session:, argv:)
        raise Hatchbox::Error, "#{name} never called describe, so it can't run." unless meta

        command = new(session: session, argv: argv)
        command.prepare
        command.call
      rescue Hatchbox::UsageError => e
        raise Hatchbox::Error, "Usage: hatchbox #{meta[:usage]}\n#{e.message}"
      end
    end

    def initialize(session:, argv:)
      @session = session
      @argv = argv
    end

    def prepare
      usage_error(args.problem) if args.problem
      wanted = positional_app
      @session = Hatchbox::Session.new(app_flag: wanted, remote_flag: session.remote_flag) if wanted && Hatchbox.blank?(session.app_flag)
    end

    private

    attr_reader :session, :argv

    def meta
      self.class.meta
    end

    def parsed
      @parsed ||= Hatchbox::Arguments::Parser.new(flags: meta[:flags], lenient: meta[:lenient]).parse(argv)
    end

    def options
      @options ||= Hatchbox::Options.new(flags: meta[:flags], values: parsed.options)
    end

    def args
      @args ||= Hatchbox::Arguments.new(specs: meta[:args], values: parsed.positionals)
    end

    def passthru
      parsed.passthru
    end

    def positional_app
      args.app if meta[:args].any? { |spec| spec.name == :app }
    end

    def usage_error(message)
      raise Hatchbox::UsageError, message
    end

    def confirm(expected:, lines:)
      ui.confirm(expected: expected, supplied: options.fetch(:confirm), lines: lines, prompt: prompt)
    end
  end
end
