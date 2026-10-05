# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Add < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe "domains:add",
          summary: "add a domain to the app",
          args: { hostname: "HOSTNAME" },
          help: ["Accounts on a trial need a card on file before Hatchbox adds a domain."]

        def call
          name = args.hostname
          ui.action("Adding #{name} to #{label}") { client.post("/apps/#{app_id}/domains", body: { "domain" => { "name" => name } }) }
          ips = targets
          ui.warning("Configure your app's DNS provider to point #{name} at #{formatter.list(ips)}") if ips.any?
          0
        end
      end
    end
  end
end
