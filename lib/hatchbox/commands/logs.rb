# frozen_string_literal: true

module Hatchbox
  module Commands
    class Logs < Hatchbox::Command
      SOURCES = ["app", "systemd"].freeze

      describe("logs",
        summary: "display recent log output",
        flags: [
          ["-n", "--num NUM", "number of lines to display", Integer],
          ["-t", "--tail", "continually stream logs"],
          ["-f", "--follow", "same as --tail"],
          ["-d", "--dyno DYNO", "only this process or copy of it, like sidekiq or server.2, or a run.ID"],
          ["-p", "--process-type TYPE", "only this process type"],
          [nil, "--ps TYPE", "same as --process-type"],
          ["-s", "--source SOURCE", "only app lines, or only systemd lines about starting and stopping"],
          [nil, "--server SERVER", "only the server with this name, id or role"],
          [nil, "--since WHEN", "only lines since this, anything journalctl --since takes, like '1 hour ago'"],
          [nil, "--units", "list the systemd units it would read on each server, and stop"],
          [nil, "--force-colors", "force use of colors even on non-tty output"]
        ],
        help: [
          "Hatchbox keeps no runtime logs and has no API for them, so this goes to every",
          "server the app's processes run on over SSH and reads the journal of each",
          "process's systemd unit, which Hatchbox names APP-PROCESS. Lines from every server",
          "are merged by time. It reaches the servers as the deploy user, with the same",
          "ssh_user, ssh_host and ssh_port overrides as hatchbox ps:exec.",
          "",
          "app lines are the process's own output. systemd lines are systemd saying it",
          "started, stopped or crashed the process."
        ],
        examples: [
          "$ hatchbox logs --tail",
          "2026-09-19T15:04:05.123456+00:00 app[server.1]: Started GET \"/\" for 203.0.113.9",
          "2026-09-19T15:04:06.000000+00:00 systemd[sidekiq.1]: Started fpd-sidekiq.service.",
          "",
          "$ hatchbox logs -p sidekiq -n 500 --since '1 hour ago'"
        ])

      def call
        usage_error("One process at a time.") if positionals.length > 1
        wanted = positionals.first
        raise Hatchbox::Error, "logs reads the running app. A Hatchbox log id goes to hatchbox releases:output #{wanted}" if wanted.to_s =~ /\A[0-9]+\z/

        source = options[:source]
        raise Hatchbox::Error, "--source takes app or systemd." unless Hatchbox.blank?(source) || SOURCES.include?(source)

        planner = Hatchbox::Logs::Planner.new(session: session, dyno: options[:dyno], server: options[:server])
        Hatchbox::Logs::Reader.new(
          plans: planner.plans(type: options[:process_type] || options[:ps] || wanted),
          lines: options[:num] || 100,
          follow: options[:tail] || options[:follow],
          since: options[:since],
          source: source,
          units_only: options[:units],
          colors: options[:force_colors] || Hatchbox.color?
        ).run
      end
    end
  end
end
