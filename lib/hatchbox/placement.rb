# frozen_string_literal: true

module Hatchbox
  Placement = Struct.new(:process, :server, keyword_init: true) do
    def label
      Hatchbox.blank?(server["name"]) ? process["name"].to_s : "#{process["name"]}@#{server["name"]}"
    end
  end
end
