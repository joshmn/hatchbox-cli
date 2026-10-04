# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Exec < Hatchbox::Command
        describe("ps:exec",
          summary: "open an SSH session on one of the app's servers",
          usage: "ps:exec [COMMAND]",
          aliases: ["ssh"],
          flags: [
            ["-d", "--dyno DYNO", "the server this copy of a process is on, like sidekiq.2"],
            ["-s", "--server SERVER", "the server, by name, id or role"]
          ],
          help: [
            "Lands in the app's current release, /home/deploy/APP/current, and falls back to",
            "the home directory when nothing is deployed yet. COMMAND runs there and comes",
            "back; quote it as one argument."
          ])

        def call
          usage_error("Only one command at a time, quote it as one argument.") if positionals.length > 1
          command = positionals.first
          target = ssh_target(dyno: options[:dyno], server: options[:server])
          $stderr.puts("Connecting to #{target.label} on #{label}...") if command.nil?
          script = "#{target.enter(separator: "; ")}#{command || "exec ${SHELL:-/bin/bash} -l"}"
          Hatchbox.run(target.ssh(command: script, tty: command.nil?, extra: passthru))
        end
      end
    end
  end
end
