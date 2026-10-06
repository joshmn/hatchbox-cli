# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        class Set < Hatchbox::Command
          include Hatchbox::Commands::Servers::Roles::Change

          describe "servers:roles:set",
            summary: "replace a server's roles with the ones given",
            usage: "servers:roles:set SERVER ROLE [ROLE ...]",
            args: { server: "SERVER", roles: "ROLE..." },
            flags: [CLUSTER_FLAG, DESTRUCTIVE_FLAG, WAIT_FLAG],
            help: [
              "Roles:",
              *ROLES.each_slice(5).map { |slice| "  #{slice.join(", ")}" },
              "",
              "A change that destroys data needs the server's name typed back."
            ]

          private

          def desired(server:, roles:)
            roles
          end
        end
      end
    end
  end
end
