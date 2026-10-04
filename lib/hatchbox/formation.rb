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

    def dynos(process = nil)
      pool = process ? [process] : processes
      pool.flat_map do |row|
        servers_for(row).each_with_index.map { |server, index| Hatchbox::Dyno.new(process: row, server: server, index: index + 1) }
      end
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

    def find_dyno(wanted)
      type, _dot, number = wanted.to_s.rpartition(".")
      type, number = wanted.to_s, nil if type.empty? || number !~ /\A[0-9]+\z/
      process = find_process(type)
      pool = dynos(process)
      raise Hatchbox::Error, "#{process["name"]} runs on no active server, #{where(process)}." if pool.empty?
      return pool.first if number.nil?

      found = pool.find { |dyno| dyno.index == number.to_i }
      raise Hatchbox::Error, "There is no #{wanted}. #{process["name"]} runs as #{pool.map { |dyno| dyno.name }.join(", ")}." unless found

      found
    end

    private

    def names_line
      return "This app has no processes." if processes.empty?

      "Processes: #{processes.map { |row| row["name"] }.join(", ")}"
    end
  end
end
