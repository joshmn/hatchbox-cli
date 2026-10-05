# frozen_string_literal: true

module Hatchbox
  module Commands
    module Maintenance
      class On < Hatchbox::Command
        describe "maintenance:on",
          summary: "put the app into maintenance mode"

        def call
          ui.action("Enabling maintenance mode for #{label}") { client.post("/apps/#{app_id}/maintenance") }
          0
        end
      end
    end
  end
end
