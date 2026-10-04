# frozen_string_literal: true

module Hatchbox
  module Commands
    module Firewall
      class Add < Hatchbox::Command
        include Hatchbox::Commands::Servers::Lookup

        MAX_PORT = 65_535

        describe "firewall:add",
          summary: "add a firewall rule to a server",
          usage: "firewall:add SERVER PORT",
          args: { server: "SERVER", port: "PORT" },
          app: :optional,
          flags: [
            CLUSTER_FLAG,
            [nil, "--from ADDRESS", "an IP address or CIDR range, anywhere unless you pass one"],
            [nil, "--deny", "deny the traffic instead of allowing it"],
            [nil, "--description TEXT", "a note for yourself"],
            WAIT_FLAG
          ],
          examples: ["$ hatchbox firewall:add web-1 9000 --from 203.0.113.0/24 --description 'Metrics scraper'", "Allowing port 9000 from 203.0.113.0/24 on web-1... done"]

        def call
          server = find_server(args.server)
          port = args.port
          raise Hatchbox::Error, "#{port} is not a port." unless port =~ /\A[0-9]+\z/ && port.to_i <= MAX_PORT

          action = options.deny ? "deny" : "allow"
          body = { "port" => port.to_i, "action" => action }
          body["from"] = options.from unless Hatchbox.blank?(options.from)
          body["description"] = options.description unless Hatchbox.blank?(options.description)
          data = client.post(server_path(server, suffix: "firewall_rules"), body: { "firewall_rule" => body }).json || {}
          message = "#{action == "deny" ? "Denying" : "Allowing"} port #{port} from #{options.from || "anywhere"} on #{server["name"]}"
          return queued(message: message, log_id: data["log_id"]) unless Hatchbox.blank?(data["log_id"])

          ui.action(message) { nil }
          0
        end
      end
    end
  end
end
