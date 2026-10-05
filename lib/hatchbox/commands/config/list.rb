# frozen_string_literal: true

module Hatchbox
  module Commands
    module Config
      class List < Hatchbox::Command
        describe "config",
          summary: "display the config vars set on an app",
          aliases: ["config:list"],
          flags: [JSON_FLAG],
          help: [
            "Hatchbox's API only returns config var names, never their values. Values set",
            "with hatchbox config:set still reach the servers."
          ]

        def call
          names = app.env_var_names
          return print_json(names) if json?

          ui.header("#{label} Config Vars")
          names.each { |name| puts(color.green(name)) }
          0
        end
      end
    end
  end
end
