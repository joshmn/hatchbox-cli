# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      class Remove < Hatchbox::Command
        include Hatchbox::Commands::Domains::Paths

        describe("domains:remove",
          summary: "remove a domain from the app",
          usage: "domains:remove HOSTNAME",
          aliases: ["domains:delete"])

        def call
          name = one_positional("HOSTNAME")
          ui.action("Removing #{name} from #{label}") { client.delete(domain_path(name)) }
          0
        end
      end
    end
  end
end
