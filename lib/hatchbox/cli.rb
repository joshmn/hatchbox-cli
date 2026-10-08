# frozen_string_literal: true

module Hatchbox
  class Cli
    class << self
      def start(argv)
        call(argv).to_i
      rescue Hatchbox::Error => e
        Hatchbox::Ui.error(e.message)
        1
      rescue Errno::EPIPE
        0
      rescue Interrupt
        $stderr.puts
        130
      end

      def call(argv)
        new(argv).call
      end
    end

    def initialize(argv)
      @argv = argv
    end

    def call
      Hatchbox::Plugins.load
      flags = Hatchbox::GlobalFlags.new(argv).parse
      rest = flags.rest
      name = rest.shift
      return version if flags.version?
      return help(rest.first) if name.nil? || name == "help"
      return help(name) if flags.help?
      return commands if name == "commands"
      return version if name == "version"

      command = Hatchbox::Registry.find(name)
      unknown(name) unless command
      dispatch(command: command, session: Hatchbox::Session.new(app_flag: flags.app, remote_flag: flags.remote), argv: rest)
    end

    private

    attr_reader :argv

    def dispatch(command:, session:, argv:)
      code = command.call(session: session, argv: argv)
      return code if code.is_a?(Integer)

      code == false ? 1 : 0
    rescue Hatchbox::Error, Errno::EPIPE
      raise
    rescue StandardError => e
      source = Hatchbox::Registry.source_of(command)
      raise unless source

      raise Hatchbox::Error, "#{command.meta[:name]} crashed in the #{source} plugin: #{e.class}: #{e.message}\n#{Array(e.backtrace).first}"
    end

    def help(name)
      Hatchbox.blank?(name) ? Hatchbox::Help.root : Hatchbox::Help.show(name)
      0
    end

    def commands
      Hatchbox::Help.commands
      0
    end

    def version
      puts(Hatchbox.platform)
      0
    end

    def unknown(name)
      lines = ["`#{name}` is not a hatchbox command."]
      guess = Hatchbox::Registry.suggest(name)
      lines << "Perhaps you meant `#{guess}`." if guess
      lines << "See `hatchbox help` for a list of available commands."
      raise Hatchbox::Error, lines.join("\n")
    end
  end
end
