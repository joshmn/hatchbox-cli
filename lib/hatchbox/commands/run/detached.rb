# frozen_string_literal: true

module Hatchbox
  module Commands
    module Run
      class Detached < Hatchbox::Command
        describe "run:detached",
          summary: "run a command on a server in the background",
          usage: "run:detached COMMAND",
          args: { command: "[COMMAND...]" },
          ssh: :shell,
          lenient: true,
          flags: [
            ["-e", "--env ENV", "environment variables to set, like FOO=bar;BAZ=qux", :many],
            ["-s", "--server SERVER", "the server to run on, by name, id or role"]
          ],
          help: [
            "Starts the command with nohup and setsid so it outlives the SSH session, and",
            "sends its output to the journal through systemd-cat, tagged so hatchbox logs",
            "--run ID reads it back."
          ],
          examples: ["$ hatchbox run:detached rake db:backfill", "Running `rake db:backfill` on fpd... done, run 20260919150405", "Run hatchbox logs --app fpd --run 20260919150405 to view the output."]

        def call
          text = (args.command + passthru).join(" ")
          usage_error("Must specify COMMAND.") if text.strip.empty?

          command = Hatchbox::RemoteCommand.new(text: text, env: options.env)
          target = ssh_target(server: options.server)
          run_id = Time.now.utc.strftime("%Y%m%d%H%M%S")
          script = script_for(command: command, target: target, ident: Hatchbox::Logs::Planner.run_ident(app: app, run_id: run_id))
          code = nil
          ui.action("Running `#{text}` on #{label}") do |step|
            code = Hatchbox.run(target.ssh(command: target.login_shell(script)))
            step.status = code.zero? ? "done, run #{run_id}" : color.red("failed", io: $stderr)
          end
          return code unless code.zero?

          puts("Run hatchbox logs --app #{app.slug || app_id} --run #{run_id} to view the output.")
          0
        end

        private

        def script_for(command:, target:, ident:)
          inner = command.rails? ? command.rails_exec : command.text
          [
            command.rails? ? target.enter_or_stop : target.enter(separator: " || true"),
            command.exports,
            "setsid nohup systemd-cat -t #{Shellwords.escape(ident)} bash -lc #{Shellwords.escape(inner)} </dev/null >/dev/null 2>&1 &",
            "echo started"
          ].reject { |part| part.empty? }.join("\n")
        end
      end
    end
  end
end
