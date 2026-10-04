# frozen_string_literal: true

module Hatchbox
  module Commands
    module Domains
      module Paths
        private

        def domain_path(name)
          "/apps/#{app_id}/domains/#{URI.encode_www_form_component(name).gsub("+", "%20").gsub("%2A", "*")}"
        end

        def targets
          servers = app.servers.select { |server| server["state"].to_s == "active" }
          fronts = servers.select { |server| Array(server["roles"]).include?("load_balancer") }
          fronts = servers.select { |server| Array(server["roles"]).include?("web") } if fronts.empty?
          fronts.map { |server| server["public_ip"].to_s }.reject { |ip| ip.empty? }
        rescue Hatchbox::Error
          []
        end
      end
    end
  end
end
