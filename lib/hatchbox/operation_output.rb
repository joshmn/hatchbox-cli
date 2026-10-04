# frozen_string_literal: true

module Hatchbox
  class OperationOutput
    def initialize(app: nil)
      @app = app
      @seen = {}
      @headers = {}
    end

    def update(log)
      emit(key: "parent", text: log["body"].to_s)
      (log["child_logs"] || []).each do |child|
        text = child["body"].to_s
        id = child["id"]
        if !text.empty? && !headers[id]
          puts
          puts(Hatchbox::Color.cyan("Output from #{server_label(child)}"))
          headers[id] = true
        end
        emit(key: "child-#{id}", text: text)
      end
    end

    def print_log(log)
      body = log["body"].to_s
      print(body)
      puts if !body.empty? && !body.end_with?("\n")
      (log["child_logs"] || []).each do |child|
        text = child["body"].to_s
        next if text.empty?

        puts
        puts(Hatchbox::Color.cyan("Output from #{server_label(child)}"))
        print(text)
        puts unless text.end_with?("\n")
      end
      $stdout.flush
    end

    def report_failure(result)
      log = result.log || {}
      children = (log["child_logs"] || []).reject { |child| child["body"].to_s.empty? }
      pool = children.select { |child| child["state"].to_s != "completed" }
      pool = children if pool.empty?
      if pool.empty?
        text = log["body"].to_s
        $stderr.print(text)
        $stderr.puts unless text.empty? || text.end_with?("\n")
      else
        pool.each { |child| report_child(child) }
      end
      Hatchbox::Ui.error("#{log["name"] || "The operation"} #{result.state || "failed"}. The full log is hatchbox releases:output #{log["id"]}")
    end

    private

    attr_reader :app, :seen, :headers

    def report_child(child)
      $stderr.puts("Output from #{server_label(child)}")
      $stderr.print(child["body"].to_s)
      $stderr.puts unless child["body"].to_s.end_with?("\n")
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

    def server_label(child)
      return "server #{child["loggable_id"]}" unless app

      app.server_name(child["loggable_id"])
    end
  end
end
