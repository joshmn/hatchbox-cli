# frozen_string_literal: true

module Hatchbox
  module Help
    module Page
      SSH_NOTES = {
        shell: [
          "Uses SSH. It connects to one of the app's servers as the deploy user, so your",
          "key has to be on that server. A user, host or port under ssh.REMOTE for this",
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
        "The app comes from -a/--app, then -r/--remote (a remote saved for this repo), then",
        "HATCHBOX_APP, then the repo's default remote. Remotes, defaults and SSH settings",
        "live in ~/.hatchbox, keyed by repo; hatchbox help git:remote explains it. The token",
        "comes from HATCHBOX_API_TOKEN, then ~/.hatchbox.",
        "postgresql:COMMAND works anywhere pg:COMMAND does. Commands marked (ssh) connect",
        "to your servers over SSH.",
        "",
        "Environment:",
        "  HATCHBOX_API_TOKEN     overrides the token in ~/.hatchbox",
        "  HATCHBOX_APP           app to use when -a and -r are left off",
        "  HATCHBOX_SSH_OPTIONS   extra ssh flags, like '-i ~/.ssh/hatchbox'",
        "  NO_COLOR               turns colors off"
      ].freeze

      class << self
        def topic(topic:, command:)
          if command
            command(command)
          else
            puts("Usage: hatchbox #{topic}:COMMAND")
            puts
            puts(" #{Hatchbox::Help::TOPICS[topic]}") if Hatchbox::Help::TOPICS[topic]
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
