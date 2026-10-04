# frozen_string_literal: true

module Hatchbox
  module Commands
    module Maintenance
      class On < Hatchbox::Command
        describe("maintenance:on",
          summary: "put the app into maintenance mode",
          help: [
            "Caddy serves a maintenance page instead of the app. The processes keep running.",
            "The change is queued on the web and load balancer servers, so a server can take",
            "a moment to catch up. Running it again reapplies it."
          ])

        def call
          none!
          ui.action("Enabling maintenance mode for #{label}") { client.post("/apps/#{app_id}/maintenance") }
          0
        end
      end
    end
  end
end
