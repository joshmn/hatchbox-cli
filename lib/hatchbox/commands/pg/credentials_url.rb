# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      class CredentialsUrl < Hatchbox::Command
        include Hatchbox::Commands::Pg::Tools

        describe "pg:credentials:url",
          summary: "show the connection information for a database",
          usage: "pg:credentials:url [DATABASE]",
          args: { database: "[DATABASE]" },
          aliases: ["pg:credentials"]

        def call
          record = postgres(args.database)
          text = connection_text(record)
          database = Hatchbox::Database.new(text)
          puts("Connection information for #{record["name"]}.")
          puts("Connection info string:")
          puts("   \"dbname=#{database.name} host=#{database.host} port=#{database.port} user=#{database.user} password=#{database.password} sslmode=#{database.sslmode}\"")
          puts("Connection URL:")
          puts("   #{text}")
          ui.warning("That host is the database's own machine, so these only work from the servers. hatchbox pg:psql tunnels to it.") if Hatchbox.blank?(record["public_connection_uri"])
          0
        end
      end
    end
  end
end
