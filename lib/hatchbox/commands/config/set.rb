# frozen_string_literal: true

module Hatchbox
  module Commands
    module Config
      class Set < Hatchbox::Command
        describe "config:set",
          summary: "set one or more config vars",
          usage: "config:set KEY1=VALUE1 [KEY2=VALUE2 ...]",
          args: { pairs: "KEY=VALUE..." },
          help: [
            "Names are uppercased before they're sent and can only use letters, numbers and",
            "underscores. A value typed here lands in your shell history like anything else",
            "on the command line."
          ],
          examples: ["$ hatchbox config:set RAILS_ENV=production RACK_ENV=production", "Setting RAILS_ENV, RACK_ENV on fpd... done", "RAILS_ENV: production", "RACK_ENV:  production"]

        def call
          vars = args.pairs.map { |pair| pair_for(pair) }
          names = vars.map { |var| var["name"] }
          ui.action("Setting #{names.join(", ")} on #{label}") { client.put("/apps/#{app_id}/env_vars", body: { "env_vars" => vars }) }
          printer.styled_hash(vars.map { |var| [color.green(var["name"]), var["value"]] })
          0
        end

        private

        def pair_for(text)
          name, separator, value = text.partition("=")
          usage_error("#{text} is invalid. Must be in the format KEY=VALUE.") if separator.empty? || name.empty?

          { "name" => Hatchbox::EnvVarName.clean(name), "value" => value }
        end
      end
    end
  end
end
