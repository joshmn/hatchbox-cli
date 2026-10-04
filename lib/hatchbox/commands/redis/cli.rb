# frozen_string_literal: true

module Hatchbox
  module Commands
    module Redis
      class Cli < Hatchbox::Command
        include Hatchbox::Commands::DatabaseConnection

        describe("redis:cli",
          summary: "open a redis-cli session to the app's redis",
          usage: "redis:cli [DATABASE]",
          flags: [[nil, "--direct", "connect straight to the redis host instead of through an SSH tunnel"]],
          help: ["Tunnels through the server holding redis, like pg:psql. redis-cli's own arguments go after --."])

        def call
          usage_error("One database at a time.") if positionals.length > 1
          record = attached(positionals.first, engines: ["redis"])
          with_connection(record, role: "redis") do |database, host, port|
            argv = ["redis-cli", "-h", host, "-p", port]
            argv << "--tls" if database.scheme == "rediss"
            argv.concat(["-n", database.name]) if database.name =~ /\A[0-9]+\z/
            argv.concat(["--user", database.user]) unless Hatchbox.blank?(database.user)
            argv.concat(passthru)
            env = Hatchbox.blank?(database.password) ? {} : { "REDISCLI_AUTH" => database.password }
            Hatchbox.run(argv, env: env)
          end
        end
      end
    end
  end
end
