# frozen_string_literal: true

module Hatchbox
  module Commands
    module Auth
      class Logout < Hatchbox::Command
        describe "auth:logout",
          summary: "clear the saved API token",
          aliases: ["logout"],
          app: false,
          help: ["Removes the saved token from ~/.hatchbox."]

        def call
          store = Hatchbox::TokenStore.new(prompt: prompt)
          ui.action("Logging out") { store.forget }
          ui.warning("HATCHBOX_API_TOKEN is still set in your environment, so commands will keep working until you unset it.") unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
          0
        end
      end
    end
  end
end
