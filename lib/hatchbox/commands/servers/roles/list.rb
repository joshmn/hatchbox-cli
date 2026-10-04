# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        class List < Hatchbox::Command
          include Hatchbox::Commands::Servers::Lookup

          describe("servers:roles",
            summary: "list a server's roles",
            usage: "servers:roles SERVER",
            app: :optional,
            flags: [CLUSTER_FLAG])

          def call
            server = find_server(one_positional("SERVER"))
            Array(server["roles"]).each { |role| puts(role) }
            0
          end
        end
      end
    end
  end
end
