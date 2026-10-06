# frozen_string_literal: true

module Hatchbox
  module Commands
    module Apps
      class Create < Hatchbox::Command
        describe "apps:create",
          summary: "create a new app on a cluster",
          usage: "apps:create NAME",
          args: { name: "[NAME]" },
          aliases: ["create"],
          app: false,
          flags: [
            ["-c", "--cluster CLUSTER", "cluster to create the app on, by name or id"],
            ["-t", "--team TEAM", "account the cluster belongs to, by name or id"],
            [nil, "--repo REPO", "repository to deploy, e.g. myuser/my-app"],
            ["-b", "--branch BRANCH", "branch to deploy, main unless you say otherwise"],
            [nil, "--git-provider PROVIDER", "connected git account to deploy from, by name, provider:name or id"],
            [nil, "--no-remote", "do not save the app as a remote for this repo"]
          ],
          help: [
            "Creates the app with auto-deploy off. Inside a git repo, the app is saved in",
            "~/.hatchbox as a remote for that repo, named with -r, or production if you",
            "leave -r off."
          ],
          examples: ["$ hatchbox apps:create my-app --cluster netcup --repo myuser/my-app --git-provider joshmn", "Creating my-app on netcup... done", "set remote production to 14001-my-app for ~/code/my-app in ~/.hatchbox"]

        def call
          name = args.name || session.app_flag
          usage_error("Must specify NAME.") if Hatchbox.blank?(name)
          Hatchbox.check_name!(name)

          catalog = session.catalog
          account = catalog.find_account(options.team)
          cluster = pick_cluster(catalog: catalog, account: account)
          body = { "cluster_id" => cluster["id"], "name" => name }
          body["branch"] = options.branch unless Hatchbox.blank?(options.branch)
          body["repo_path"] = options.repo unless Hatchbox.blank?(options.repo)
          body["connected_account_id"] = catalog.find_git_provider(options.git_provider, account: account)["id"] unless Hatchbox.blank?(options.git_provider)
          created = ui.action("Creating #{name} on #{cluster["name"]}") { client.post("/apps", body: { "app" => body }).json || {} }
          slug = "#{created["id"]}-#{created["name"] || name}"
          options.no_remote ? puts(slug) : remember(slug)
          0
        end

        private

        def pick_cluster(catalog:, account:)
          wanted = options.cluster
          clusters = catalog.clusters_for(account)
          return only_cluster(clusters) if Hatchbox.blank?(wanted)

          found = catalog.find_cluster(wanted, accounts: [account])
          raise Hatchbox::Error, (["No cluster called #{wanted}. Clusters:"] + cluster_lines(clusters)).join("\n") unless found

          found
        end

        def only_cluster(clusters)
          return clusters.first if clusters.length == 1
          raise Hatchbox::Error, "That account has no clusters. Make one on the dashboard first." if clusters.empty?

          raise Hatchbox::Error, (["Pick a cluster with --cluster:"] + cluster_lines(clusters)).join("\n")
        end

        def cluster_lines(clusters)
          clusters.map { |row| "#{row["name"]} (#{row["id"]})" }
        end

        def remember(slug)
          return puts(slug) unless Hatchbox::ProjectRoot.repo

          remote = Hatchbox.blank?(session.remote_flag) ? "production" : session.remote_flag
          existing = config.app_for(remote)
          return ui.warning("Remote #{remote} is already set to #{existing} for #{config.location}, so it was left alone. Save this app under another remote with hatchbox git:remote -a #{slug} -r NAME.") unless Hatchbox.blank?(existing)

          config.set_app(remote: remote, app: slug)
          puts("set remote #{remote} to #{slug} for #{config.location}")
        end
      end
    end
  end
end
