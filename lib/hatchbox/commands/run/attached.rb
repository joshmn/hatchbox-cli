# frozen_string_literal: true

module Hatchbox
  module Commands
    module Run
      class Attached < Hatchbox::Command
        describe "run",
          summary: "run a command on one of the app's servers",
          usage: "run COMMAND",
          args: { command: "[COMMAND...]" },
          ssh: :shell,
          lenient: true,
          flags: [
            ["-e", "--env ENV", "environment variables to set, like FOO=bar;BAZ=qux", :many],
            ["-s", "--server SERVER", "the server to run on, by name, id or role"],
            [nil, "--no-tty", "force the command to not run in a tty"],
            ["-x", "--exit-code", "passthrough the exit code of the remote command, which it always does"]
          ],
          help: [
            "Runs the command over SSH on the first server carrying an app role, or the one",
            "-s picks, through a login shell, from the app's current release. A command",
            "starting with rails runs as bin/rails and stops if the release directory is",
            "missing. Flags meant for the command go after --."
          ],
          examples: ["$ hatchbox run rails console", "Running `rails console` on fpd... up, web-1", "", "$ hatchbox run -- ls -la"]

        def call
          text = (args.command + passthru).join(" ")
          usage_error("Must specify COMMAND.") if text.strip.empty?

          command = Hatchbox::RemoteCommand.new(text: text, env: options.env)
          target = ssh_target(server: options.server)
          script = [exports(command), script_for(command: command, target: target)].reject { |part| part.empty? }.join("\n")
          ui.action("Running `#{text}` on #{label}") { |step| step.status = "up, #{target.label}" }
          Hatchbox.run(target.ssh(command: target.login_shell(script), tty: tty?))
        end

        private

        def tty?
          !options.no_tty && $stdin.tty? && $stdout.tty?
        end

        def exports(command)
          command.exports
        rescue Hatchbox::RemoteCommand::InvalidEnv => e
          usage_error(e.message)
        end

        def script_for(command:, target:)
          return "#{target.enter(separator: "\n")}#{command.text}" unless command.rails?

          "#{target.enter_or_stop}\n#{command.rails_exec}"
        end
      end
    end
  end
end
