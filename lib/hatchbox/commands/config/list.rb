# frozen_string_literal: true

module Hatchbox
  module Commands
    module Config
      class List < Hatchbox::Command
        describe("config",
          summary: "display the config vars set on an app",
          aliases: ["config:list"],
          flags: [JSON_FLAG],
          help: [
            "Hatchbox's API returns config var names and never their values, so this lists",
            "names. Values set here still reach the servers."
          ])

        def call
          none!
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
