# frozen_string_literal: true

module Hatchbox
  module Logs
    class Planner
      PALETTE = [36, 32, 33, 35, 34, 31].freeze

      class << self
        def run_ident(app:, run_id:)
          "#{app.name}-run-#{run_id}"
        end
      end

      def initialize(session:, run_id:, server:)
        @session = session
        @run_id = run_id.to_s
        @server = server
      end

      def plans(type:)
        return run_plans unless run_id.empty?

        formation = app.formation
        raise Hatchbox::Error, "#{app.label} has no processes, so there is no journal to read." if formation.processes.empty?

        placements = pick(formation: formation, type: type)
        return [pinned_plan(placements)] if Hatchbox::SshTarget.pinned?(session)

        placements = on_server(placements) unless Hatchbox.blank?(server)
        raise Hatchbox::Error, "Those processes run on no active server." if placements.empty?

        placements.group_by { |row| row.server["id"] }.map do |_id, group|
          Hatchbox::Logs::Plan.new(
            target: Hatchbox::SshTarget.new(session: session, server: group.first.server),
            units: group.to_h { |row| [unit(row.process), { name: row.label, color: color(row.process) }] },
            identifiers: {}
          )
        end
      end

      private

      attr_reader :session, :run_id, :server

      def app
        session.app
      end

      def pick(formation:, type:)
        return formation.placements(formation.find_process(type)) unless Hatchbox.blank?(type)

        formation.placements
      end

      def on_server(placements)
        found = app.fleet.find_server(server)
        picked = placements.select { |row| row.server["id"] == found["id"] }
        raise Hatchbox::Error, "None of those processes run on #{found["name"]}." if picked.empty?

        picked
      end

      def pinned_plan(placements)
        processes = placements.empty? ? app.formation.processes : placements.map { |row| row.process }.uniq
        units = processes.to_h { |process| [unit(process), { name: process["name"].to_s, color: color(process) }] }
        Hatchbox::Logs::Plan.new(target: Hatchbox::SshTarget.new(session: session), units: units, identifiers: {})
      end

      def run_plans
        ident = self.class.run_ident(app: app, run_id: run_id)
        servers = Hatchbox::SshTarget.pinned?(session) ? [nil] : run_servers
        servers.map do |picked|
          Hatchbox::Logs::Plan.new(
            target: Hatchbox::SshTarget.new(session: session, server: picked),
            units: {},
            identifiers: { ident => { name: "run #{run_id}", color: 34 } }
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
