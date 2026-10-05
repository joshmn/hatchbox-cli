# frozen_string_literal: true

module Hatchbox
  module Commands
    module Auth
      class Token < Hatchbox::Command
        describe "auth:token",
          summary: "display the API token in use",
          app: false,
          help: ["Prints the token hatchbox would use here."]

        def call
          puts(session.token)
          0
        end
      end
    end
  end
end
