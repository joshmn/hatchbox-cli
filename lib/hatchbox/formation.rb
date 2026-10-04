# frozen_string_literal: true

module Hatchbox
  class Formation
    attr_reader :processes, :fleet

    def initialize(processes:, fleet:)
      @processes = processes
      @fleet = fleet
    end

    def servers_for(process)
      pinned = process["server_id"]
      return fleet.servers.select { |server| server["id"].to_s == pinned.to_s } unless Hatchbox.blank?(pinned)

      fleet.with_roles(Array(process["roles"]).map { |role| role.to_s })
    end

    def placements(process = nil)
      pool = process ? [process] : processes
      pool.flat_map { |row| servers_for(row).map { |server| Hatchbox::Placement.new(process: row, server: server) } }
    end

    def where(process)
      pinned = process["server_id"]
      return "server #{fleet.label(pinned)}" unless Hatchbox.blank?(pinned)

      roles = Array(process["roles"]).map { |role| role.to_s }
      return "nowhere" if roles.empty?

      "#{roles.length == 1 ? "role" : "roles"} #{roles.join(", ")}"
    end

    def find_process(wanted)
      raise Hatchbox::Error, "Which process?\n#{names_line}" if Hatchbox.blank?(wanted)
      raise Hatchbox::Error, "This app has no processes." if processes.empty?

      text = wanted.to_s.downcase
      exact = processes.find { |row| row["name"].to_s.downcase == text || row["id"].to_s == text }
      return exact if exact

      near = processes.select { |row| row["name"].to_s.downcase.include?(text) }
      return near.first if near.length == 1
      raise Hatchbox::Error, "#{wanted} matches more than one process: #{near.map { |row| row["name"] }.join(", ")}." if near.length > 1

      raise Hatchbox::Error, "No process named #{wanted}.\n#{names_line}"
    end

    private

    def names_line
      return "This app has no processes." if processes.empty?

      "Processes: #{processes.map { |row| row["name"] }.join(", ")}"
    end
  end
end
