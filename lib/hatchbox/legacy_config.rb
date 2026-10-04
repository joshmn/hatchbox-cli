# frozen_string_literal: true

module Hatchbox
  class LegacyConfig
    def initialize(text)
      @text = text
    end

    def to_h
      found = {}
      text.each_line do |line|
        key, separator, value = line.strip.partition("=")
        next if separator.empty? || key.start_with?("#") || Hatchbox.blank?(value.strip)

        store(found: found, key: key.strip, value: value.strip)
      end
      found
    end

    private

    attr_reader :text

    def store(found:, key:, value:)
      if key == "token"
        found["token"] = value
      elsif key.start_with?("token:")
        (found["tokens"] ||= {})[key.delete_prefix("token:")] = value
      end
    end
  end
end
