# frozen_string_literal: true

module Hatchbox
  module Commands
    module Auth
      class Login < Hatchbox::Command
        describe "auth:login",
          summary: "log in with a Hatchbox API token",
          aliases: ["login"],
          app: false,
          flags: [[nil, "--token TOKEN", "use this token instead of asking for one, which puts it in your shell history"]],
          help: [
            "Hatchbox's API has no password login, so this asks for an API token, checks it",
            "against your accounts, and saves it to ~/.hatchbox. Make one at",
            "https://hatchbox.io/api_tokens."
          ],
          examples: ["$ hatchbox login", "Enter your Hatchbox API token. Make one at https://hatchbox.io/api_tokens", "Token:", "Logging in... done", "Logged in with access to My Team"]

        def call
          store = Hatchbox::TokenStore.new(prompt: prompt)
          token = Hatchbox.blank?(options.token) ? store.ask : options.token
          accounts = []
          ui.action("Logging in") { accounts = store.verify(token) }
          store.save(token)
          puts("Logged in with access to #{formatter.list(accounts.map { |account| account["name"] })}")
          ui.warning("HATCHBOX_API_TOKEN is set in your environment, and it wins over #{store.path} until you unset it.") unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
          0
        end
      end
    end
  end
end
