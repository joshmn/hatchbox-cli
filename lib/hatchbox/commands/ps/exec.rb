# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Exec < Hatchbox::Command
        describe "ps:exec",
          summary: "open an SSH session on one of the app's servers",
          args: { command: "[COMMAND]" },
          ssh: :shell,
          aliases: ["ssh"],
          flags: [SERVER_FLAG],
          help: [
            "Lands in the app's current release, /home/deploy/APP/current, and falls back to",
            "the home directory when nothing is deployed yet. COMMAND runs there and comes",
            "back; quote it as one argument."
          ]

        def call
          command = args.command
          target = ssh_target(server: options.server)
          $stderr.puts("Connecting to #{target.label} on #{label}...") if command.nil?
          script = "#{target.enter(separator: "; ")}#{command || "exec ${SHELL:-/bin/bash} -l"}"
          Hatchbox.run(target.ssh(command: script, tty: command.nil?, extra: passthru))
        end
      end
    end
  end
end
