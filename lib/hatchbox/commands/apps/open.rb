# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Open < Hatchbox::Command
        describe "apps:open",
          summary: "open the app in a web browser",
          args: { path: "[PATH]" },
          aliases: ["open"],
          help: ["Opens the app's first domain over https. Wildcard domains are skipped."]

        def call
          base = app.web_url
          raise Hatchbox::Error, "#{label} has no domains, or only wildcard ones, so there is nothing to open. Add one with hatchbox domains:add." unless base

          url = "#{base.chomp("/")}/#{args.path.to_s.sub(%r{\A/}, "")}"
          opener = RbConfig::CONFIG["host_os"] =~ /darwin/ ? "open" : "xdg-open"
          ui.action("Opening #{url}") { Hatchbox.run([opener, url]) }
          0
        end
      end
    end
  end
end
