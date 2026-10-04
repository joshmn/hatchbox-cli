# frozen_string_literal: true

module Hatchbox
  module Commands
    module Maintenance
      class Off < Hatchbox::Command
        describe "maintenance:off",
          summary: "take the app out of maintenance mode"

        def call
          ui.action("Disabling maintenance mode for #{label}") { client.delete("/apps/#{app_id}/maintenance") }
          0
        end
      end
    end
  end
end
