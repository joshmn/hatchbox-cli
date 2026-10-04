# frozen_string_literal: true

module Hatchbox
  module Commands
    module Config
      class Unset < Hatchbox::Command
        describe "config:unset",
          summary: "unset one or more config vars",
          usage: "config:unset KEY1 [KEY2 ...]",
          args: { keys: "KEY..." },
          aliases: ["config:remove"]

        def call
          names = args.keys.map { |name| Hatchbox::EnvVarName.clean(name) }
          ui.action("Unsetting #{names.join(", ")} on #{label}") { client.delete("/apps/#{app_id}/env_vars", body: { "env_vars" => names }) }
          0
        end
      end
    end
  end
end
