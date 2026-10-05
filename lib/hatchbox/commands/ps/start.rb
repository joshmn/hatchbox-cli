# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Start < Hatchbox::Command
        describe "ps:start",
          summary: "turn a stopped process back on",
          args: { type: "TYPE" },
          flags: [WAIT_FLAG]

        def call
          process = app.formation.find_process(args.type)
          data = client.post("/apps/#{app_id}/processes/#{process["id"]}/activation").json || {}
          queued_or_done(message: "Starting #{process["name"]} on #{label}", log_id: data["log_id"], status: "done, it was already on")
        end
      end
    end
  end
end
