# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        class Add < Hatchbox::Command
          include Hatchbox::Commands::Servers::Roles::Change

          describe "servers:roles:add",
            summary: "give a server more roles",
            usage: "servers:roles:add SERVER ROLE [ROLE ...]",
            args: { server: "SERVER", roles: "ROLE..." },
            flags: [CLUSTER_FLAG, DESTRUCTIVE_FLAG, WAIT_FLAG],
            help: ["hatchbox help servers:roles:set lists the roles."]

          private

          def desired(server:, roles:)
            Array(server["roles"]).map { |role| role.to_s } | roles
          end
        end
      end
    end
  end
end
