# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Roles
        class Set < Hatchbox::Command
          include Hatchbox::Commands::Servers::Roles::Change

          describe "servers:roles:set",
            summary: "set a server's roles, adding and removing to match",
            usage: "servers:roles:set SERVER ROLE [ROLE ...]",
            args: { server: "SERVER", roles: "ROLE..." },
            app: :optional,
            flags: [CLUSTER_FLAG, DESTRUCTIVE_FLAG, WAIT_FLAG],
            help: [
              "Roles are app, web, worker, cron, load_balancer, postgresql, mysql, redis,",
              "memcached and elasticsearch. Adding an app role deploys every app in the cluster.",
              "Removing a database role uninstalls it and destroys its data, and so does",
              "dropping a server's last app role when it holds sqlite databases; those need",
              "the server's name typed back."
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
