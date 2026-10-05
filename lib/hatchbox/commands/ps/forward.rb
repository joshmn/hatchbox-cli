# frozen_string_literal: true

module Hatchbox
  module Commands
    module Ps
      class Forward < Hatchbox::Command
        describe "ps:forward",
          summary: "forward traffic on a local port to a server",
          usage: "ps:forward PORT[,PORT...]",
          args: { ports: "PORT" },
          ssh: :shell,
          flags: [["-p", "--local-port PORT", "local port to use, comma separated to match PORT"], SERVER_FLAG],
          examples: ["$ hatchbox ps:forward 9090", "SSH tunnel established.", "Forwarding localhost:9090 to web-1:9090", "Use CTRL+C to stop port forwarding"]

        def call
          remote = args.ports.split(",")
          local = Hatchbox.blank?(options.local_port) ? remote : options.local_port.split(",")
          usage_error("--local-port needs as many ports as PORT has.") unless local.length == remote.length
          raise Hatchbox::Error, "Ports are numbers." unless (remote + local).all? { |port| port =~ /\A[0-9]+\z/ }

          target = ssh_target(server: options.server)
          forwards = local.zip(remote).flat_map { |mine, theirs| ["-L", "127.0.0.1:#{mine}:localhost:#{theirs}"] }
          $stderr.puts("SSH tunnel established.")
          local.zip(remote).each { |mine, theirs| $stderr.puts("Forwarding localhost:#{mine} to #{target.label}:#{theirs}") }
          $stderr.puts("Use CTRL+C to stop port forwarding")
          Hatchbox.run(target.ssh(extra: ["-N", "-o", "ExitOnForwardFailure=yes"] + forwards))
        end
      end
    end
  end
end
