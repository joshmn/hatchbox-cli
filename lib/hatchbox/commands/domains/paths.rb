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
          fleet = app.fleet
          fronts = fleet.with_roles(["load_balancer"])
          fronts = fleet.with_roles(["web"]) if fronts.empty?
          fronts.map { |server| server["public_ip"].to_s }.reject { |ip| ip.empty? }
        rescue Hatchbox::Error
          []
        end
      end
    end
  end
end
