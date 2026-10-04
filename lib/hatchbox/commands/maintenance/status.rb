# frozen_string_literal: true

module Hatchbox
  module Commands
    module Maintenance
      class Status < Hatchbox::Command
        describe "maintenance",
          summary: "display the current maintenance status of an app"

        def call
          puts(formatter.yes_no(app.details["maintenance"]))
          0
        end
      end
    end
  end
end
