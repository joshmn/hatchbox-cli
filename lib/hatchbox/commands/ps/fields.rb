# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      module Fields
        FLAGS = [
          [nil, "--name NAME", "process name, letters, numbers, hyphens and underscores"],
          [nil, "--start COMMAND", "the command that runs"],
          [nil, "--stop COMMAND", "command systemd runs to stop it"],
          [nil, "--reload COMMAND", "command systemd runs to reload it"],
          [nil, "--roles LIST", "comma-separated roles; it runs on every server holding one of them"],
          [nil, "--server SERVER", "one server to run on instead of roles, by name or id"],
          [nil, "--systemd-type TYPE", "simple or oneshot"],
          [nil, "--[no-]socket", "systemd socket activation, at most one process per app"],
          [nil, "--[no-]restart-on-deploy", "restart it on every deploy, which is the default"],
          [nil, "--[no-]appsignal", "run it under appsignal-wrap, which needs AppSignal connected"],
          [nil, "--appsignal-options OPTIONS", "extra flags for appsignal-wrap"]
        ].freeze

        MAP = {
          name: "name",
          start: "start_command",
          stop: "stop_command",
          reload: "reload_command",
          systemd_type: "systemd_type",
          socket: "socket",
          restart_on_deploy: "restart_on_deploy",
          appsignal: "appsignal",
          appsignal_options: "appsignal_options"
        }.freeze

        private

        def process_body
          body = {}
          MAP.each { |flag, field| body[field] = options[flag] if options.key?(flag) }
          body["roles"] = options.roles.split(",").map { |role| role.strip }.reject { |role| role.empty? } if options.key?(:roles)
          body["server_id"] = server_id_for(options.server) if options.key?(:server)
          raise Hatchbox::Error, "A process runs on --roles or on one --server, not both." if body.key?("roles") && body.key?("server_id") && body["roles"].any?

          Hatchbox.check_name!(body["name"]) if body.key?("name")
          body
        end

        def server_id_for(wanted)
          return wanted if wanted.to_s =~ /\A[0-9]+\z/

          found = app.servers.find { |server| server["name"].to_s.casecmp?(wanted.to_s) }
          raise Hatchbox::Error, "No server called #{wanted} on #{label}'s cluster.\n#{app.fleet.listing}" unless found

          found["id"]
        end

        def show(process)
          printer.styled_hash([
            ["Id", process["id"].to_s],
            ["Runs On", app.formation.where(process)],
            ["Start", process["start_command"]],
            ["Stop", process["stop_command"]],
            ["Reload", process["reload_command"]],
            ["Systemd Type", process["systemd_type"]],
            ["On Deploy", process["restart_on_deploy"] ? "restarts" : "left alone"]
          ])
        end
      end
    end
  end
end
