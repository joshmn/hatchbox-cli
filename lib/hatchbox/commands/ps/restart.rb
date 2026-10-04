# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Restart < Hatchbox::Command
        describe("ps:restart",
          summary: "restart every process, or one process type",
          usage: "ps:restart [TYPE]",
          aliases: ["restart"],
          flags: [WAIT_FLAG],
          help: [
            "Hatchbox restarts a process on every server it runs on, so server.2 restarts",
            "server everywhere."
          ])

        def call
          usage_error("One process type at a time.") if positionals.length > 1
          return restart_all if positionals.empty?

          process = app.formation.find_process(positionals.first.sub(/\.[0-9]+\z/, ""))
          log_id = (client.post("/apps/#{app_id}/processes/#{process["id"]}/restart").json || {})["id"]
          queued(message: "Restarting #{process["name"]} on #{label}", log_id: log_id)
        end

        private

        def restart_all
          log_id = (client.post("/apps/#{app_id}/restart").json || {})["id"]
          queued(message: "Restarting all processes on #{label}", log_id: log_id)
        end
      end
    end
  end
end
