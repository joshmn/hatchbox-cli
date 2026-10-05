# frozen_string_literal: true

module Hatchbox
  module Commands
    module Pg
      module Backups
        class Schedule < Hatchbox::Command
          include Hatchbox::Commands::Pg::Backups::Tools

          PROVIDERS = ["local", "s3", "azureblob", "r2", "spaces", "gcs", "wasabi", "other"].freeze
          FIELDS = {
            at: "backup_frequency",
            provider: "backup_provider",
            region: "backup_region",
            bucket: "backup_bucket",
            endpoint: "backup_endpoint",
            access_key_id: "backup_access_key_id",
            secret_access_key: "backup_secret_access_key",
            retention: "backup_retention_period",
            honeybadger_checkin_id: "honeybadger_checkin_id",
            appsignal_push_api_key: "appsignal_app_push_api_key"
          }.freeze

          describe "pg:backups:schedule",
            summary: "schedule backups, or change where and how often they run",
            usage: "pg:backups:schedule [DATABASE] --at SCHEDULE",
            args: { database: "[DATABASE]" },
            flags: [
              [nil, "--at SCHEDULE", "cron expression or @hourly, @daily, @weekly, @monthly"],
              [nil, "--provider PROVIDER", "local, s3, azureblob, r2, spaces, gcs, wasabi or other"],
              [nil, "--bucket BUCKET", "bucket or container, for every provider but local"],
              [nil, "--region REGION", "for s3, spaces and wasabi"],
              [nil, "--endpoint URL", "for other, and optionally r2"],
              [nil, "--access-key-id KEY", "access key, or the storage account name on Azure"],
              [nil, "--secret-access-key SECRET", "secret key, asked for when you leave it off"],
              [nil, "--retention PERIOD", "how long to keep them, like 7d or 6M"],
              [nil, "--honeybadger-checkin-id ID", "Honeybadger check-in to report runs to"],
              [nil, "--appsignal-push-api-key KEY", "AppSignal push key to monitor runs with"]
            ],
            help: [
              "Only the settings you pass change, but every call turns backups on, so the first",
              "one needs the provider and its settings. Hatchbox never returns credentials."
            ],
            examples: [
              "$ hatchbox pg:backups:schedule --at @daily --provider s3 --region us-east-1 --bucket my-backups --access-key-id AKIA... --retention 7d",
              "Secret access key:",
              "Scheduling backups of DATABASE_URL (db_56237b230774)... done"
            ]

          def call
            record = one_database
            body = {}
            FIELDS.each { |flag, field| body[field] = options[flag] if options.key?(flag) }
            usage_error("Nothing to change. Pass --at, --provider and the rest.") if body.empty?
            raise Hatchbox::Error, "#{body["backup_provider"]} is not a provider Hatchbox takes: #{PROVIDERS.join(", ")}." if body.key?("backup_provider") && !PROVIDERS.include?(body["backup_provider"])

            ask_secret(body: body, record: record)
            data = client.patch("/databases/#{record["id"]}/backup_configuration", body: { "backup_configuration" => body }).json || {}
            message = "Scheduling backups of #{title_for(record)} (#{record["name"]})"
            queued_or_done(message: message, log_id: data["log_id"])
          end

          private

          def ask_secret(body:, record:)
            return if body.key?("backup_secret_access_key") || !body.key?("backup_provider") || body["backup_provider"] == "local"
            return if backup_configuration(record)["backup_credentials_set"] && !body.key?("backup_access_key_id")
            return unless prompt.available?

            secret = prompt.secret(question: "Secret access key: ")
            body["backup_secret_access_key"] = secret unless Hatchbox.blank?(secret)
          end
        end
      end
    end
  end
end
