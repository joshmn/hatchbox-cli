# frozen_string_literal: true

module Hatchbox
  module Commands
    module Auth
      class Whoami < Hatchbox::Command
        describe("auth:whoami",
          summary: "display the accounts the API token can reach",
          aliases: ["whoami"],
          app: false,
          help: [
            "Hatchbox's API has no endpoint that says who a token belongs to, so this lists",
            "the accounts it can act on and where the token came from."
          ])

        def call
          none!
          accounts = client.get("/accounts").json || []
          accounts.each { |account| puts("#{account["name"]} (#{account["id"]})") }
          ui.note("token from #{Hatchbox::TokenStore.new.source(env: session.remote_flag)}")
          0
        end
      end
    end
  end
end
