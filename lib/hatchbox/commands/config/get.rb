# frozen_string_literal: true

module Hatchbox
  module Commands
    module Config
      class Get < Hatchbox::Command
        describe "config:get",
          summary: "check whether a config var is set",
          args: { key: "KEY" },
          help: [
            "Hatchbox never returns config var values, so this can only say whether KEY is",
            "set, and exits 1 either way."
          ]

        def call
          key = args.key.upcase
          raise Hatchbox::Error, "#{key} is set on #{label}, but Hatchbox never returns config var values." if app.env_var_names.include?(key)

          raise Hatchbox::Error, "#{key} is not set on #{label}."
        end
      end
    end
  end
end
