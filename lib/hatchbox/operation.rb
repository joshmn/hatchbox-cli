# frozen_string_literal: true

module Hatchbox
  class Operation
    FINISHED = ["completed", "failed", "aborted"].freeze
    POLL_SECONDS = 3
    MAX_WAIT_SECONDS = 3600

    Result = Struct.new(:log, :state, :gone, keyword_init: true) do
      def ok?
        gone || state == "completed"
      end
    end

    def initialize(client:, app: nil)
      @client = client
      @app = app
      @seen = {}
      @headed = {}
    end

    def fetch(log_id)
      client.get("/logs/#{log_id}").json || {}
    end

    def wait(log_id, gone_ok: false)
      poll(log_id, gone_ok: gone_ok) { |_log| nil }
    end

    def stream(log_id, gone_ok: false)
      poll(log_id, gone_ok: gone_ok) { |log| update(log) }
    end

    def print_log(log)
      write(io: $stdout, text: log["body"].to_s)
      children(log).each do |child|
        heading(child)
        write(io: $stdout, text: child["body"].to_s)
      end
      $stdout.flush
    end

    def report_failure(result)
      log = result.log || {}
      pool = children(log).reject { |child| child["state"].to_s == "completed" }
      pool = children(log) if pool.empty?
      if pool.empty?
        write(io: $stderr, text: log["body"].to_s)
      else
        pool.each do |child|
          $stderr.puts("Output from #{server_label(child)}")
          write(io: $stderr, text: child["body"].to_s)
        end
      end
      Hatchbox::Ui.error("#{log["name"] || "The operation"} #{result.state || "failed"}. Read the full log with hatchbox releases:output #{log["id"]}")
    end

    private

    attr_reader :client, :app, :seen, :headed

    def poll(log_id, gone_ok:)
      waited = 0
      loop do
        response = client.raw(method: "GET", path: "/logs/#{log_id}")
        return Result.new(log: nil, state: "completed", gone: true) if response.code == 404 && gone_ok
        raise Hatchbox::Error, client.error_message(response) unless response.ok?

        log = response.json || {}
        yield(log)
        state = log["state"].to_s
        return Result.new(log: log, state: state, gone: false) if FINISHED.include?(state)
        raise Hatchbox::Error, gave_up_message(log_id: log_id, state: state) if waited >= MAX_WAIT_SECONDS

        sleep(POLL_SECONDS)
        waited += POLL_SECONDS
      end
    rescue Interrupt
      $stderr.puts
      Hatchbox::Ui.warning("Stopped watching. It keeps running on Hatchbox; pick it back up with hatchbox releases:output #{log_id}")
      raise
    end

    def gave_up_message(log_id:, state:)
      "Gave up watching after #{MAX_WAIT_SECONDS / 60} minutes, still #{state}.\nPick it back up with hatchbox releases:output #{log_id}"
    end

    def update(log)
      emit(key: "parent", text: log["body"].to_s)
      (log["child_logs"] || []).each do |child|
        text = child["body"].to_s
        id = child["id"]
        unless text.empty? || headed[id]
          heading(child)
          headed[id] = true
        end
        emit(key: "child-#{id}", text: text)
      end
    end

    def emit(key:, text:)
      old = seen[key].to_s
      if old.empty?
        print(text) unless text.empty?
      elsif text.length > old.length && text.start_with?(old)
        print(text[old.length..-1])
      elsif text != old
        print(text)
      end
      $stdout.flush
      seen[key] = text
    end

    def children(log)
      (log["child_logs"] || []).reject { |child| child["body"].to_s.empty? }
    end

    def heading(child)
      puts
      puts(Hatchbox::Color.cyan("Output from #{server_label(child)}"))
    end

    def write(io:, text:)
      io.print(text)
      io.puts unless text.empty? || text.end_with?("\n")
    end

    def server_label(child)
      return "server #{child["loggable_id"]}" unless app

      app.server_name(child["loggable_id"])
    end
  end
end
