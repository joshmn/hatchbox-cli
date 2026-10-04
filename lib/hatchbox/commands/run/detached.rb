# frozen_string_literal: true

module Hatchbox
  module Commands
    module Run
      class Detached < Hatchbox::Command
        describe("run:detached",
          summary: "run a command on a server in the background",
          usage: "run:detached COMMAND",
          lenient: true,
          flags: [
            ["-e", "--env ENV", "environment variables to set, like FOO=bar;BAZ=qux", :many],
            ["-s", "--server SERVER", "the server to run on, by name, id or role"],
            ["-d", "--dyno DYNO", "run on the server this copy of a process is on, like sidekiq.2"]
          ],
          help: [
            "Starts the command with nohup and setsid so it outlives the SSH session, and",
            "sends its output to the journal through systemd-cat, tagged so hatchbox logs",
            "--dyno run.ID reads it back."
          ],
          examples: ["$ hatchbox run:detached rake db:backfill", "Running `rake db:backfill` on fpd... done, run.20260919150405", "Run hatchbox logs --app fpd --dyno run.20260919150405 to view the output."])

        def call
          text = (positionals + passthru).join(" ")
          usage_error("Must specify COMMAND.") if text.strip.empty?

          command = Hatchbox::RemoteCommand.new(text: text, env: options[:env])
          target = ssh_target(dyno: options[:dyno], server: options[:server])
          dyno = "run.#{Time.now.utc.strftime("%Y%m%d%H%M%S")}"
          script = script_for(command: command, target: target, ident: "#{app.name}-#{dyno.tr(".", "-")}")
          code = nil
          ui.action("Running `#{text}` on #{label}") do |step|
            code = Hatchbox.run(target.ssh(command: target.login_shell(script)))
            step.status = code.zero? ? "done, #{dyno}" : ui.paint("failed", code: 31)
          end
          return code unless code.zero?

          puts("Run hatchbox logs --app #{app.slug || app_id} --dyno #{dyno} to view the output.")
          0
        end

        private

        def script_for(command:, target:, ident:)
          inner = command.rails? ? command.rails_exec : command.text
          [
            command.rails? ? target.enter_or_stop : target.enter(separator: " || true"),
            exports(command),
            "setsid nohup systemd-cat -t #{Shellwords.escape(ident)} bash -lc #{Shellwords.escape(inner)} </dev/null >/dev/null 2>&1 &",
            "echo started"
          ].reject { |part| part.empty? }.join("\n")
        end

        def exports(command)
          command.exports
        rescue Hatchbox::RemoteCommand::InvalidEnv => e
          usage_error(e.message)
        end
      end
    end
  end
end
