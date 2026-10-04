# frozen_string_literal: true

module Hatchbox
  class Operation
    def initialize(client:, app: nil)
      @client = client
      @output = Hatchbox::OperationOutput.new(app: app)
    end

    def fetch(log_id)
      client.get("/logs/#{log_id}").json || {}
    end

    def wait(log_id, gone_ok: false)
      poll(log_id, gone_ok: gone_ok) { |_log| nil }
    end

    def stream(log_id, gone_ok: false)
      poll(log_id, gone_ok: gone_ok) { |log| output.update(log) }
    end

    def print_log(log)
      output.print_log(log)
    end

    def report_failure(result)
      output.report_failure(result)
    end

    private

    attr_reader :client, :output

    def poll(log_id, gone_ok:)
      waited = 0
      loop do
        response = client.raw(method: "GET", path: "/logs/#{log_id}")
        return Hatchbox::OperationResult.new(log: nil, state: "completed", gone: true) if response.code == 404 && gone_ok
        raise Hatchbox::Error, client.error_message(response) unless response.ok?

        log = response.json || {}
        yield(log)
        state = log["state"].to_s
        return Hatchbox::OperationResult.new(log: log, state: state, gone: false) if Hatchbox::FINISHED.include?(state)
        raise Hatchbox::Error, gave_up_message(log_id: log_id, state: state) if waited >= Hatchbox::MAX_WAIT_SECONDS

        sleep(Hatchbox::POLL_SECONDS)
        waited += Hatchbox::POLL_SECONDS
      end
    rescue Interrupt
      $stderr.puts
      Hatchbox::Ui.warning("Stopped watching. It keeps running on Hatchbox; pick it back up with hatchbox releases:output #{log_id}")
      raise
    end

    def gave_up_message(log_id:, state:)
      "Gave up watching after #{Hatchbox::MAX_WAIT_SECONDS / 60} minutes, still #{state}.\nPick it back up with hatchbox releases:output #{log_id}"
    end
  end
end
