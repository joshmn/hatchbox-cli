# frozen_string_literal: true

module Hatchbox
  module Commands
    module Tracking
      RELEASE_KINDS = {
        "deploy" => Hatchbox::Activity::DEPLOY,
        "deploys" => Hatchbox::Activity::DEPLOY,
        "restart" => "Apps::Restart",
        "restarts" => "Apps::Restart"
      }.freeze

      private

      def operation
        @operation ||= Hatchbox::Operation.new(client: client, app: log_app)
      end

      def log_app
        return nil unless meta[:app]

        app
      rescue Hatchbox::Error
        nil
      end

      def queued(message:, log_id:, gone_ok: false)
        raise Hatchbox::Error, "Hatchbox accepted it but returned no log id." if Hatchbox.blank?(log_id)
        return done(message: message, status: "done, queued as #{log_id}") if options.fetch(:no_wait)

        result = nil
        ui.action(message) do |step|
          result = operation.wait(log_id, gone_ok: gone_ok)
          step.status = status_for(result)
        end
        return 0 if result.ok?

        operation.report_failure(result)
        1
      end

      def queued_or_done(message:, log_id:, status: "done")
        return queued(message: message, log_id: log_id) unless Hatchbox.blank?(log_id)

        done(message: message, status: status)
      end

      def done(message:, status: "done")
        ui.action(message) { |step| step.status = status }
        0
      end

      def follow_deploy(log_id)
        result = operation.stream(log_id)
        $stdout.puts
        ui.action("Verifying deploy") { |step| step.status = status_for(result) }
        return 0 if result.ok?

        ui.error("The deploy #{result.state}. Read it again with hatchbox releases:output #{log_id}")
        1
      end

      def show_log(log, deploy: false)
        running = !Hatchbox::Operation::FINISHED.include?(log["state"].to_s)
        return follow_deploy(log["id"]) if running && deploy
        return operation.stream(log["id"]).ok? ? 0 : 1 if running

        operation.print_log(log)
        log["state"] == "completed" ? 0 : 1
      end

      def status_for(result)
        result.ok? ? "done" : color.red(result.state.to_s, io: $stderr)
      end

      def resolve_log(wanted, kind: nil)
        text = wanted.to_s
        return text if text =~ /\A[0-9]+\z/

        name = Hatchbox.blank?(text) ? kind : RELEASE_KINDS[text]
        raise Hatchbox::Error, "#{text} is not a release id, deploy or restart. hatchbox releases lists the ids." if !Hatchbox.blank?(text) && name.nil?

        rows = client.get("/apps/#{app_id}/logs?limit=100").json || []
        found = name ? rows.find { |row| row["name"] == name } : rows.first
        raise Hatchbox::Error, "#{label} has no #{release_noun(name)} on record." unless found

        found["id"].to_s
      end

      def release_noun(name)
        name ? Hatchbox::Activity.humanize(name).downcase : "releases"
      end
    end
  end
end
