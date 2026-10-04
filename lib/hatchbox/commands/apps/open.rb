# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Open < Hatchbox::Command
        describe("apps:open",
          summary: "open the app in a web browser",
          usage: "apps:open [PATH]",
          aliases: ["open"],
          help: ["Opens the first of the app's domains over https."])

        def call
          usage_error("Only one path at a time.") if positionals.length > 1
          base = app.web_url
          raise Hatchbox::Error, "#{label} has no domains, so there is nothing to open. Add one with hatchbox domains:add." unless base

          url = "#{base.chomp("/")}/#{positionals.first.to_s.sub(%r{\A/}, "")}"
          opener = RbConfig::CONFIG["host_os"] =~ /darwin/ ? "open" : "xdg-open"
          ui.action("Opening #{url}") { Hatchbox.run([opener, url]) }
          0
        end
      end
    end
  end
end
