# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Socks < Hatchbox::Command
        describe("ps:socks",
          summary: "launch a SOCKS proxy into one of the app's servers",
          flags: [
            ["-p", "--port PORT", "local port for the proxy, 1080 unless you say otherwise"],
            ["-d", "--dyno DYNO", "the server this copy of a process is on"],
            ["-s", "--server SERVER", "the server, by name, id or role"]
          ])

        def call
          none!
          port = options[:port] || "1080"
          target = ssh_target(dyno: options[:dyno], server: options[:server])
          $stderr.puts("SOCKSv5 proxy server started on port #{port}")
          $stderr.puts("Use CTRL+C to stop the proxy")
          Hatchbox.run(target.ssh(extra: ["-N", "-o", "ExitOnForwardFailure=yes", "-D", "127.0.0.1:#{port}"]))
        end
      end
    end
  end
end
