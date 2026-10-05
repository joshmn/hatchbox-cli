# frozen_string_literal: true

module Hatchbox
  module Commands
    class Deploy < Hatchbox::Command
      describe "deploy",
        summary: "deploy the app's branch, or one commit, and stream the build",
        usage: "deploy",
        args: { status: "[status]" },
        flags: [
          [nil, "--sha SHA", "deploy this commit instead of the tip of the branch"],
          WAIT_FLAG,
          [nil, "--no-follow", "same as --no-wait"],
          [nil, "--watch", "stream the log, which it does anyway"],
          [nil, "--status", "same as hatchbox status"]
        ],
        examples: ["$ hatchbox deploy", "Deploying main to fpd... queued, release 4212", "-----> Starting deployment", "...", "Verifying deploy... done"]

      def call
        return Hatchbox::Commands::Status.call(session: session, argv: []) if options.status || args.status == "status"

        usage_error("Unexpected argument: #{args.status}") if args.status
        sha = options.sha
        ref = Hatchbox.blank?(sha) ? app.details["branch"] : sha[0, 7]
        log_id = nil
        ui.action("Deploying #{ref} to #{label}") do |step|
          log_id = (client.post("/apps/#{app_id}/deploy", body: Hatchbox.blank?(sha) ? nil : { "sha" => sha }).json || {})["id"]
          raise Hatchbox::Error, "Hatchbox accepted the deploy but returned no log id." if Hatchbox.blank?(log_id)

          step.status = detached? ? "done, queued as #{log_id}" : "queued, release #{log_id}"
        end
        return 0 if detached?

        follow_deploy(log_id)
      end

      private

      def detached?
        options.no_wait || options.no_follow
      end
    end
  end
end
