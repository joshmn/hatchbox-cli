# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Update < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe "domains:update",
          summary: "rename one of the app's domains",
          args: { hostname: "HOSTNAME", new_hostname: "NEWHOSTNAME" }

        def call
          old = args.hostname
          name = args.new_hostname
          ui.action("Renaming #{old} to #{name} on #{label}") { client.patch(domain_path(old), body: { "domain" => { "name" => name } }) }
          0
        end
      end
    end
  end
end
