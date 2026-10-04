# frozen_string_literal: true

module Hatchbox
  module Commands
    module Releases
      class Rollback < Hatchbox::Command
        describe("releases:rollback",
          summary: "redeploy the commit of an earlier release",
          usage: "releases:rollback [RELEASE]",
          aliases: ["rollback"],
          flags: [WAIT_FLAG],
          help: [
            "Without RELEASE, goes back to the newest successful deploy of a different commit",
            "than the one live now. Hatchbox has no releases to restore, so this is a deploy of",
            "that commit: config vars, processes and databases stay as they are."
          ])

        def call
          usage_error("One release at a time.") if positionals.length > 1
          deploys = (client.get("/apps/#{app_id}/logs?limit=100").json || []).select { |row| rollbackable?(row) }
          live = deploys.first
          chosen = positionals.empty? ? previous(deploys) : lookup(positionals.first)
          sha = chosen["commit_sha"].to_s
          log_id = nil
          ui.action("Rolling back #{label} to #{chosen["id"]} (#{sha[0, 7]})") do |step|
            log_id = (client.post("/apps/#{app_id}/deploy", body: { "sha" => sha }).json || {})["id"]
            step.status = options[:no_wait] ? "done, queued as #{log_id}" : "queued, release #{log_id}"
          end
          ui.warning("Rollback redeploys that commit. Config vars, processes and databases are left as they are.")
          ui.warning("To undo, run: hatchbox releases:rollback #{live["id"]}") if live
          return 0 if options[:no_wait]

          follow_deploy(log_id)
        end

        private

        def rollbackable?(row)
          Hatchbox::Activity.deploy?(row) && row["state"] == "completed" && !Hatchbox.blank?(row["commit_sha"])
        end

        def previous(deploys)
          current = app.details["last_deploy_sha"].to_s
          found = deploys.find { |row| row["commit_sha"].to_s != current }
          raise Hatchbox::Error, "There is no earlier successful deploy of a different commit in the last 100 releases." unless found

          found
        end

        def lookup(wanted)
          log = operation.fetch(resolve_log(wanted))
          raise Hatchbox::Error, "Release #{log["id"]} is not a deploy, so there is no commit to roll back to." unless Hatchbox::Activity.deploy?(log) && !Hatchbox.blank?(log["commit_sha"])
          raise Hatchbox::Error, "Release #{log["id"]} belongs to another app." unless log["loggable_id"].to_s == app_id.to_s

          log
        end
      end
    end
  end
end
