# frozen_string_literal: true

module Hatchbox
  module Commands
    module Servers
      module Lookup
        CLUSTER_FLAG = [nil, "--cluster CLUSTER", "the cluster, by name or id, instead of the app's"].freeze
        CONFIRM_FLAG = [nil, "--confirm SERVER", "the server's name, to skip the prompt"].freeze

        private

        def cluster_record
          @cluster_record ||= Hatchbox.blank?(options.cluster) ? app.cluster : named_cluster(options.cluster)
        end

        def named_cluster(wanted)
          catalog = session.catalog
          found = catalog.find_cluster(wanted, accounts: catalog.usable_accounts)
          raise Hatchbox::Error, "Couldn't find that cluster." unless found

          client.get("/clusters/#{found["id"]}").json || {}
        end

        def find_server(wanted)
          servers = cluster_record["servers"] || []
          found = Hatchbox::Fleet.new(servers: servers).match(wanted)
          return found if found

          raise Hatchbox::Error, "No server called #{wanted} on #{cluster_record["name"]}.\nServers: #{servers.map { |server| server["name"] }.join(", ")}"
        end

        def server_path(server, suffix: nil)
          base = "/clusters/#{cluster_record["id"]}/servers/#{server["id"]}"
          suffix ? "#{base}/#{suffix}" : base
        end
      end
    end
  end
end
