# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Update < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe("domains:update",
          summary: "rename one of the app's domains",
          usage: "domains:update HOSTNAME NEWHOSTNAME")

        def call
          usage_error("Must specify HOSTNAME and NEWHOSTNAME.") unless positionals.length == 2

          old, name = positionals
          ui.action("Updating #{old} to #{name} on #{label}") { client.patch(domain_path(old), body: { "domain" => { "name" => name } }) }
          0
        end
      end
    end
  end
end
