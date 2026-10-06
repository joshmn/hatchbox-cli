# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Update < Hatchbox::Command
        FIELDS = {
          branch: "branch",
          repo: "repo_path",
          pre_build_script: "pre_build_script",
          build_script: "build_script",
          post_build_script: "post_build_script",
          post_deploy_script: "post_deploy_script",
          failed_deploy_script: "failed_deploy_script",
          health_check: "health_check_uri",
          dns_provider: "dns_provider",
          dns_api_user: "dns_api_user",
          dns_access_token: "dns_access_token"
        }.freeze

        describe "apps:update",
          summary: "change an app's repo, branch, deploy scripts, Caddy or DNS settings",
          flags: [
            ["-b", "--branch BRANCH", "branch to deploy"],
            [nil, "--repo REPO", "repository to deploy, e.g. myuser/my-app"],
            [nil, "--git-provider PROVIDER", "connected git account to deploy from, by name, provider:name or id"],
            [nil, "--pre-build-script SCRIPT", "script run before the build, or @FILE to read it from a file"],
            [nil, "--build-script SCRIPT", "build script, or @FILE"],
            [nil, "--post-build-script SCRIPT", "script run after the build, or @FILE"],
            [nil, "--post-deploy-script SCRIPT", "script run after the deploy, or @FILE"],
            [nil, "--failed-deploy-script SCRIPT", "script run once when a deploy fails, or @FILE"],
            [nil, "--health-check PATH", "relative path for Caddy to health check, e.g. /up"],
            [nil, "--caddyfile FILE", "Caddyfile to apply, or - to read it from stdin"],
            [nil, "--dns-provider PROVIDER", "DNS provider for certificates"],
            [nil, "--dns-api-user USER", "DNS API user"],
            [nil, "--dns-access-token TOKEN", "DNS access token"]
          ]

        def call
          body = options.fields_for(FIELDS).transform_values { |value| expand(value) }
          body["caddyfile"] = caddyfile(options.caddyfile) if options.key?(:caddyfile)
          body["connected_account_id"] = session.catalog.find_git_provider(options.git_provider, account: account)["id"] if options.key?(:git_provider)
          usage_error("Nothing to change. See hatchbox help apps:update.") if body.empty?
          raise Hatchbox::Error, "--health-check must be a relative path like /up." if body.key?("health_check_uri") && !body["health_check_uri"].to_s.start_with?("/")

          ui.action("Updating #{label}") { client.patch("/apps/#{app_id}", body: { "app" => body }) }
          printer.styled_hash(body.map { |key, value| [key, summary(key: key, value: value)] })
          ui.note("Caddy is being reapplied on the servers") if body.key?("caddyfile") || body.key?("health_check_uri")
          0
        end

        private

        def expand(value)
          text = value.to_s
          return text unless text.start_with?("@")

          read_file(text[1..-1])
        end

        def caddyfile(path)
          return $stdin.read if path == "-"

          read_file(path)
        end

        def read_file(path)
          File.read(path)
        rescue Errno::ENOENT
          raise Hatchbox::Error, "No file at #{path}."
        end

        def summary(key:, value:)
          return "(set)" if key == "dns_access_token"

          lines = value.to_s.split("\n")
          lines.length > 1 ? "#{lines.length} lines" : value.to_s
        end
      end
    end
  end
end
