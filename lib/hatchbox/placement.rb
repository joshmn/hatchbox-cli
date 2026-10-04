# frozen_string_literal: true

module Hatchbox
  class Placement
    attr_reader :process, :server

    def initialize(process:, server:)
      @process = process
      @server = server
    end

    def type
      process["name"].to_s
    end

    def label
      Hatchbox.blank?(server["name"]) ? type : "#{type}@#{server["name"]}"
    end
  end
end
