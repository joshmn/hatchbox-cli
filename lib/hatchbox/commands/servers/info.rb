# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      class Info < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        describe "servers:info",
          summary: "show one server",
          usage: "servers:info SERVER",
          args: { server: "SERVER" },
          app: :optional,
          flags: [CLUSTER_FLAG, JSON_FLAG]

        def call
          server = client.get(server_path(find_server(args.server))).json || {}
          return print_json(server) if json?

          ui.header(server["name"].to_s)
          printer.styled_hash([
            ["Id", server["id"].to_s],
            ["State", server["state"]],
            ["Roles", Array(server["roles"]).join(", ")],
            ["Cluster", cluster_record["name"]],
            ["Public IP", server["public_ip"]],
            ["Public IPv6", server["public_ipv6"]],
            ["Private IP", server["private_ip"]],
            ["SSH Port", server["ssh_port"].to_s],
            ["Size", server["size"]],
            ["OS", server["ubuntu_version"]],
            ["Provider Id", server["provider_id"]],
            ["Configured", formatter.date(server["last_configured_at"])]
          ])
          0
        end
      end
    end
  end
end
