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
          pool = catalog.usable_accounts.flat_map { |account| catalog.clusters_for(account) }
          found = pool.find { |row| row["id"].to_s == wanted.to_s || row["name"].to_s.casecmp?(wanted.to_s) }
          raise Hatchbox::Error, "Couldn't find that cluster." unless found

          client.get("/clusters/#{found["id"]}").json || {}
        end

        def find_server(wanted)
          servers = cluster_record["servers"] || []
          text = wanted.to_s.downcase
          exact = servers.find { |server| server["name"].to_s.downcase == text || server["id"].to_s == text }
          return exact if exact

          near = servers.select { |server| server["name"].to_s.downcase.include?(text) }
          return near.first if near.length == 1

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
