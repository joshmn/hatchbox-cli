# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class List < Hatchbox::Command
        describe("ps",
          summary: "list processes for an app",
          usage: "ps [TYPE [TYPE ...]]",
          flags: [JSON_FLAG],
          help: [
            "A process runs once on every active server carrying one of its roles, or on the",
            "one server it is pinned to, so each copy shows as TYPE.N. Hatchbox's API knows",
            "whether a process is enabled, not whether it is up right now; hatchbox logs and",
            "hatchbox ps:exec reach the servers for that."
          ],
          examples: ["$ hatchbox ps", "=== server (role web): bin/rails server (1)", "server.1: enabled  web-1  203.0.113.10"])

        def call
          formation = app.formation
          pool = positionals.empty? ? app.processes : positionals.map { |name| formation.find_process(name) }
          pool = pool.sort_by { |row| row["name"].to_s }
          return print_json(pool.map { |row| row.merge("dynos" => dynos_json(formation: formation, process: row)) }) if json?
          return empty if pool.empty?

          pool.each_with_index do |process, index|
            puts if index.positive?
            show(formation: formation, process: process)
          end
          0
        end

        private

        def empty
          puts("No processes on #{label}. Add one with hatchbox ps:create.")
          0
        end

        def show(formation:, process:)
          dynos = formation.dynos(process)
          ui.header("#{process["name"]} (#{formation.where(process)}): #{process["start_command"]} (#{dynos.length})")
          state = process["active"] ? color.green("enabled") : color.yellow("disabled")
          printer.columns(dynos.map { |dyno| ["#{dyno.name}:", state, dyno.server["name"], dyno.server["public_ip"]] })
          puts(color.dim("No active server carries #{formation.where(process)}.")) if dynos.empty?
        end

        def dynos_json(formation:, process:)
          formation.dynos(process).map do |dyno|
            { "name" => dyno.name, "server" => dyno.server["name"], "server_id" => dyno.server["id"], "public_ip" => dyno.server["public_ip"] }
          end
        end
      end
    end
  end
end
