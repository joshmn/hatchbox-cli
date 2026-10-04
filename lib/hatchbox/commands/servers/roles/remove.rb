# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        class Remove < Hatchbox::Command
          include Hatchbox::Commands::Servers::Roles::Change

          describe("servers:roles:remove",
            summary: "take roles off a server",
            usage: "servers:roles:remove SERVER ROLE [ROLE ...]",
            app: :optional,
            flags: [CLUSTER_FLAG, DESTRUCTIVE_FLAG, WAIT_FLAG])

          private

          def desired(server:, roles:)
            Array(server["roles"]).map { |role| role.to_s } - roles
          end
        end
      end
    end
  end
end
