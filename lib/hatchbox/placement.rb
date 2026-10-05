# frozen_string_literal: true

module Hatchbox
  class Placement
    attr_reader :process, :server

    def initialize(process:, server:)
      @process = process
      @server = server
    end

    def label
      Hatchbox.blank?(server["name"]) ? process["name"].to_s : "#{process["name"]}@#{server["name"]}"
    end
  end
end
