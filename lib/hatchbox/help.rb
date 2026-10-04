# frozen_string_literal: true

module Hatchbox
  module Help
    PRIMARY = {
      "apps" => "manage apps (create, destroy, info, rename, open)",
      "auth" => "log in and out, and see what the token reaches",
      "config" => "manage app config vars",
      "domains" => "manage the app's domains",
      "logs" => "display logs for an app, read from its servers over SSH",
      "maintenance" => "turn maintenance mode on and off",
      "pg" => "manage postgresql databases",
      "ps" => "manage processes (restart, stop, start, exec)",
      "releases" => "manage app releases and roll back",
      "run" => "run a command on one of the app's servers"
    }.freeze

    ADDITIONAL = {
      "builds" => "list the app's deploys",
      "cron" => "manage the app's cron jobs",
      "deploy" => "deploy the app and stream the build",
      "firewall" => "manage a server's firewall rules",
      "git" => "add apps to .hatchbox, list git providers",
      "mysql" => "open a mysql shell on the app's mysql",
      "redis" => "open redis-cli on the app's redis",
      "remotes" => "list the apps named in .hatchbox",
      "scripts" => "list the runs of custom scripts",
      "servers" => "manage servers, their roles and reboots",
      "status" => "show the latest deploy"
    }.freeze

    FOOTER = [
      "The app comes from -a/--app, then -r/--remote (a remote in the nearest .hatchbox),",
      "then HATCHBOX_APP, then the .hatchbox default. hatchbox help git:remote explains",
      "the file. The token comes from HATCHBOX_API_TOKEN, then ~/.hatchbox.",
      "postgresql:COMMAND works anywhere pg:COMMAND does.",
      "",
      "Environment:",
      "  HATCHBOX_API_TOKEN     overrides the token in ~/.hatchbox",
      "  HATCHBOX_APP           app to use when -a and -r are left off",
      "  HATCHBOX_SSH_OPTIONS   extra ssh flags, like '-i ~/.ssh/hatchbox'",
      "  HATCHBOX_API_BASE      defaults to https://hatchbox.io/api/v1",
      "  NO_COLOR               turns colors off"
    ].freeze

    class << self
      def root
        puts("Usage: hatchbox COMMAND [--app APP] [command-specific-options]")
        puts
        puts("Commands, type \"hatchbox help COMMAND\" for more details:")
        visible = Hatchbox::Registry.visible
        groups = visible.group_by { |klass| topic_of(klass) }
        order = PRIMARY.keys + ADDITIONAL.keys
        width = visible.map { |klass| klass.meta[:name].length }.max
        groups.keys.sort_by { |topic| [order.index(topic) || order.length, topic] }.each do |topic|
          puts
          groups[topic].sort_by { |klass| klass.meta[:name] }.each { |klass| puts("  #{klass.meta[:name].ljust(width)}  #  #{klass.meta[:summary]}") }
        end
        puts
        FOOTER.each { |line| puts(line) }
      end

      def show(name)
        name = Hatchbox::Registry.canonical(name)
        command = Hatchbox::Registry.find(name)
        topic = name.to_s.split(":").first
        return Hatchbox::HelpPage.topic(topic: topic, command: command) if command && command.meta[:name] == topic && members(topic).length > 1
        return Hatchbox::HelpPage.command(command) if command
        return Hatchbox::HelpPage.topic(topic: topic, command: nil) if members(topic).any?

        raise Hatchbox::Error, "No help for #{name}.\nSee `hatchbox help` for a list of topics."
      end

      def commands
        rows = Hatchbox::Registry.visible.sort_by { |klass| klass.meta[:name] }.map { |klass| [klass.meta[:usage], klass.meta[:summary]] }
        width = rows.map { |usage, _summary| usage.length }.max
        rows.each { |usage, summary| puts("#{usage.ljust(width)}  #  #{summary}") }
      end

      def members(topic)
        Hatchbox::Registry.visible.select { |klass| topic_of(klass) == topic }.sort_by { |klass| klass.meta[:name] }
      end

      def blurb(topic)
        PRIMARY[topic] || ADDITIONAL[topic]
      end

      private

      def topic_of(klass)
        klass.meta[:name].split(":").first
      end
    end
  end
end
