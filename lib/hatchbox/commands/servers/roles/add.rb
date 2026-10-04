# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        class Add < Hatchbox::Command
          include Hatchbox::Commands::Servers::Roles::Change

          describe("servers:roles:add",
            summary: "give a server more roles",
            usage: "servers:roles:add SERVER ROLE [ROLE ...]",
            app: :optional,
            flags: [CLUSTER_FLAG, DESTRUCTIVE_FLAG, WAIT_FLAG])

          private

          def desired(server:, roles:)
            Array(server["roles"]).map { |role| role.to_s } | roles
          end
        end
      end
    end
  end
end
