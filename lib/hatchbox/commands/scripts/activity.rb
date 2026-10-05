# frozen_string_literal: true

module Hatchbox
  module Commands
    module Scripts
      class Activity < Hatchbox::Command
        describe "scripts:activity",
          summary: "list the runs of a custom script",
          args: { script: "SCRIPT" },
          app: false,
          flags: [["-n", "--num NUM", "number of runs", Integer], JSON_FLAG],
          help: [
            "SCRIPT is the id from the script's dashboard URL, like 42 in",
            "/scripts/42-clear-the-cache. What the script printed on each server isn't here;",
            "that's in hatchbox servers:activity."
          ]

        def call
          script = args.script
          rows = client.get("/scripts/#{URI.encode_www_form_component(script)}/logs?limit=#{options.num || 20}").json || []
          return print_json(rows) if json?

          ui.header("Script #{script} Activity")
          return puts("Nothing on record.") if rows.empty?

          printer.columns(Hatchbox::Activity.rows(rows))
          0
        end
      end
    end
  end
end
