# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Add < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe "domains:add",
          summary: "add a domain to the app",
          args: { hostname: "HOSTNAME" }

        def call
          name = args.hostname
          ui.action("Adding #{name} to #{label}") { client.post("/apps/#{app_id}/domains", body: { "domain" => { "name" => name } }) }
          ips = targets
          ui.warning("Point #{name} at #{formatter.list(ips)} wherever its DNS is hosted.") if ips.any?
          0
        end
      end
    end
  end
end
