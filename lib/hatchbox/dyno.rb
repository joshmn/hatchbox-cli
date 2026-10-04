# frozen_string_literal: true

module Hatchbox
  class Dyno
    attr_reader :process, :server, :index

    def initialize(process:, server:, index:)
      @process = process
      @server = server
      @index = index
    end

    def name
      "#{type}.#{index}"
    end

    def type
      process["name"].to_s
    end
  end
end
