# frozen_string_literal: true

module Hatchbox
  module Logs
    class Planner
      PALETTE = [36, 32, 33, 35, 34, 31].freeze

      def initialize(session:, dyno:, server:)
        @session = session
        @dyno = dyno.to_s
        @server = server
      end

      def plans(type:)
        return run_plans if dyno.start_with?("run.")

        formation = app.formation
        raise Hatchbox::Error, "#{app.label} has no processes, so there is no journal to read." if formation.processes.empty?

        dynos = pick(formation: formation, type: type)
        return [pinned_plan(dynos)] if Hatchbox::SshTarget.pinned?(session)

        dynos = on_server(dynos) unless Hatchbox.blank?(server)
        raise Hatchbox::Error, "Those processes run on no active server." if dynos.empty?

        dynos.group_by { |row| row.server["id"] }.map do |_id, group|
          Hatchbox::Logs::Plan.new(
            target: Hatchbox::SshTarget.new(session: session, server: group.first.server),
            units: group.to_h { |row| [unit(row.process), { name: row.name, color: color(row.process) }] },
            identifiers: {}
          )
        end
      end

      private

      attr_reader :session, :dyno, :server

      def app
        session.app
      end

      def pick(formation:, type:)
        return [formation.find_dyno(dyno)] if dyno =~ /\.[0-9]+\z/
        return formation.dynos(formation.find_process(dyno)) unless dyno.empty?
        return formation.dynos(formation.find_process(type)) unless Hatchbox.blank?(type)

        formation.dynos
      end

      def on_server(dynos)
        found = app.fleet.find_server(server)
        picked = dynos.select { |row| row.server["id"] == found["id"] }
        raise Hatchbox::Error, "None of those processes run on #{found["name"]}." if picked.empty?

        picked
      end

      def pinned_plan(dynos)
        units = {}
        pool = dynos.empty? ? app.formation.processes.map { |process| Hatchbox::Dyno.new(process: process, server: {}, index: 1) } : dynos
        pool.each { |row| units[unit(row.process)] ||= { name: "#{row.type}.1", color: color(row.process) } }
        Hatchbox::Logs::Plan.new(target: Hatchbox::SshTarget.new(session: session), units: units, identifiers: {})
      end

      def run_plans
        ident = "#{app.name}-#{dyno.tr(".", "-")}"
        servers = Hatchbox::SshTarget.pinned?(session) ? [nil] : run_servers
        servers.map do |picked|
          Hatchbox::Logs::Plan.new(
            target: Hatchbox::SshTarget.new(session: session, server: picked),
            units: {},
            identifiers: { ident => { name: dyno, color: 34 } }
          )
        end
      end

      def run_servers
        return [app.fleet.find_server(server)] unless Hatchbox.blank?(server)

        app.fleet.app_servers
      end

      def unit(process)
        "#{app.name}-#{process["name"]}.service"
      end

      def color(process)
        index = app.processes.index(process) || 0
        PALETTE[index % PALETTE.length]
      end
    end
  end
end
