# frozen_string_literal: true

module Hatchbox
  module Help
    module Page
      SSH_NOTES = {
        shell: [
          "Uses SSH. It connects as the deploy user to one or more of the app's servers,",
          "so your key has to be on them (and should be had you provision your server through Hatchbox.",
          "A user, host or port under ssh.REMOTE for this",
          "repo in ~/.hatchbox overrides that, and HATCHBOX_SSH_OPTIONS passes extra flags."
        ],
        tunnel: [
          "Uses SSH, unless the database has a public address. The connection goes through",
          "an SSH tunnel to the server holding the database, as the deploy user. A user,",
          "host or port under ssh.REMOTE for this repo in ~/.hatchbox overrides that, and",
          "HATCHBOX_SSH_OPTIONS passes extra flags."
        ]
      }.freeze

      FOOTER = [
        "Environment:",
        "  HATCHBOX_API_TOKEN     overrides the token in ~/.hatchbox",
        "  HATCHBOX_APP           app to use when -a and -r are left off",
        "  HATCHBOX_REMOTE        remote to use when -a, -r and HATCHBOX_APP are left off",
        "  HATCHBOX_SSH_OPTIONS   extra ssh flags, like '-i ~/.ssh/hatchbox'",
        "  HATCHBOX_PLUGINS       more plugins to load, comma-separated",
        "  HATCHBOX_NO_PLUGINS    skips every plugin",
        "  NO_COLOR               turns colors off"
      ].freeze

      class << self
        def topic(topic:, command:)
          if command
            command(command)
          else
            puts("Usage: hatchbox #{topic}:COMMAND")
            summary = Hatchbox::Help.topics[topic]
            lines([summary]) if summary
          end
          others = Hatchbox::Help.members(topic).reject { |klass| klass == command }
          return if others.empty?

          puts
          puts("Additional commands, type \"hatchbox help COMMAND\" for more details:")
          puts
          width = others.map { |klass| klass.meta[:usage].length }.max
          others.each { |klass| puts("  #{klass.meta[:usage].ljust(width)}  #  #{Hatchbox::Help.summary(klass)}") }
        end

        def command(command)
          usage(command)
          meta = command.meta
          lines(Array(meta[:help])) if meta[:help]
          lines(SSH_NOTES.fetch(meta[:ssh])) if meta[:ssh]
          if meta[:aliases].any?
            puts
            puts("Aliases: #{meta[:aliases].join(", ")}")
          end
          return if meta[:examples].empty?

          puts
          puts("Examples:")
          lines(meta[:examples])
        end

        private

        def usage(command)
          meta = command.meta
          puts("Usage: hatchbox #{meta[:usage]}")
          puts
          puts(" #{meta[:summary]}")
          source = Hatchbox::Registry.source_of(command)
          puts(" from the #{Hatchbox.tilde(source)} plugin") if source
          flags = (meta[:app] ? Hatchbox::Command::APP_FLAGS.map { |spec| Hatchbox::Flag.new(spec) } : []) + meta[:flags]
          return if flags.empty?

          puts
          width = flags.map { |flag| flag.label.length }.max
          flags.each { |flag| puts(" #{flag.label.ljust(width)}  #  #{flag.description}") }
        end

        def lines(texts)
          puts
          texts.each { |line| puts(" #{line}".rstrip) }
        end
      end
    end
  end
end
