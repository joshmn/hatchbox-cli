# frozen_string_literal: true

module Hatchbox
  module Help
    TOPICS = {
      "apps" => "manage apps (create, destroy, info, rename, open)",
      "auth" => "log in and out, and see what the token reaches",
      "config" => "manage app config vars",
      "domains" => "manage the app's domains",
      "logs" => "display logs for an app, read from its servers over SSH",
      "maintenance" => "turn maintenance mode on and off",
      "pg" => "manage PostgreSQL databases",
      "ps" => "manage processes (restart, stop, start, exec)",
      "releases" => "manage app releases and roll back",
      "run" => "run a command on one of the app's servers",
      "builds" => "list the app's deploys",
      "cron" => "manage the app's cron jobs",
      "deploy" => "deploy the app and stream the build",
      "firewall" => "manage a server's firewall rules",
      "git" => "save apps as remotes for this repo, list git providers",
      "mysql" => "open a mysql shell to the app's MySQL database",
      "redis" => "open a redis-cli session to the app's Redis",
      "remotes" => "list the remotes saved for this repo",
      "scripts" => "list the runs of custom scripts",
      "servers" => "manage servers, their roles and reboots",
      "status" => "show the latest deploy"
    }.freeze

    class << self
      def root
        puts("Usage: hatchbox COMMAND [--app APP] [command-specific-options]")
        puts
        puts("Commands, type \"hatchbox help COMMAND\" for more details:")
        all = Hatchbox::Registry.commands
        groups = all.group_by { |klass| topic_of(klass) }
        order = TOPICS.keys
        width = all.map { |klass| klass.meta[:name].length }.max
        groups.keys.sort_by { |topic| [order.index(topic) || order.length, topic] }.each do |topic|
          puts
          groups[topic].sort_by { |klass| klass.meta[:name] }.each { |klass| puts("  #{klass.meta[:name].ljust(width)}  #  #{summary(klass)}") }
        end
        puts
        Hatchbox::Help::Page::FOOTER.each { |line| puts(line) }
      end

      def show(name)
        name = Hatchbox::Registry.canonical(name)
        command = Hatchbox::Registry.find(name)
        topic = name.to_s.split(":").first
        return Hatchbox::Help::Page.topic(topic: topic, command: command) if command && command.meta[:name] == topic && members(topic).length > 1
        return Hatchbox::Help::Page.command(command) if command
        return Hatchbox::Help::Page.topic(topic: topic, command: nil) if members(topic).any?

        raise Hatchbox::Error, "No help for #{name}.\nSee `hatchbox help` for a list of topics."
      end

      def commands
        rows = Hatchbox::Registry.commands.sort_by { |klass| klass.meta[:name] }.map { |klass| [klass.meta[:usage], summary(klass)] }
        width = rows.map { |usage, _summary| usage.length }.max
        rows.each { |usage, summary| puts("#{usage.ljust(width)}  #  #{summary}") }
      end

      def members(topic)
        Hatchbox::Registry.commands.select { |klass| topic_of(klass) == topic }.sort_by { |klass| klass.meta[:name] }
      end

      def summary(klass)
        klass.meta[:ssh] ? "#{klass.meta[:summary]} (ssh)" : klass.meta[:summary]
      end

      private

      def topic_of(klass)
        klass.meta[:name].split(":").first
      end
    end
  end
end
