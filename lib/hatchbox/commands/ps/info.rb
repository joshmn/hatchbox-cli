# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Info < Hatchbox::Command
        describe "ps:info",
          summary: "show one process",
          args: { type: "TYPE" },
          flags: [JSON_FLAG]

        def call
          process = app.formation.find_process(args.type)
          return print_json(process) if json?

          ui.header("#{process["name"]} on #{label}")
          printer.styled_hash([
            ["Id", process["id"].to_s],
            ["State", process["active"] ? "enabled" : "disabled"],
            ["Runs On", app.formation.where(process)],
            ["Servers", app.formation.servers_for(process).map { |server| server["name"] }],
            ["Start", process["start_command"]],
            ["Stop", process["stop_command"]],
            ["Reload", process["reload_command"]],
            ["Socket", formatter.on_off(process["socket"])],
            ["Systemd Type", process["systemd_type"]],
            ["Unit", Hatchbox::Logs::Planner.unit_name(app: app, process: process)],
            ["On Deploy", process["restart_on_deploy"] ? "restarts" : "left alone"],
            ["AppSignal", formatter.on_off(process["appsignal"])],
            ["AppSignal Options", process["appsignal_options"]],
            ["Created", formatter.date(process["created_at"])],
            ["Updated", formatter.date(process["updated_at"])]
          ])
          0
        end
      end
    end
  end
end
