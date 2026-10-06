# frozen_string_literal: true

module Hatchbox
  class Client
    API_BASE = "https://hatchbox.io/api/v1"

    def initialize(token:)
      @http = Hatchbox::Http.new(base: API_BASE, token: token)
    end

    ["GET", "POST", "PUT", "PATCH", "DELETE"].each do |verb|
      define_method(verb.downcase) { |path, body: nil| ensure_ok(raw(method: verb, path: path, body: body)) }
    end

    def raw(method:, path:, body: nil)
      http.request(method: method, path: path, body: body)
    end

    def pages(path)
      Enumerator.new do |pages|
        url = path
        until url.nil?
          response = get(url)
          pages << Array(response.json)
          url = response.next_page
        end
      end
    end

    def error_message(response)
      return "Invalid credentials provided.\nRun hatchbox login, or check HATCHBOX_API_TOKEN." if response.code == 401

      detail = error_detail(response.json)
      detail.empty? ? "Hatchbox returned HTTP #{response.code}." : sentence(detail)
    end

    private

    attr_reader :http

    def ensure_ok(response)
      return response if response.ok?

      raise Hatchbox::Error, error_message(response)
    end

    def error_detail(data)
      return "" unless data.is_a?(Hash)

      detail = data["error"].to_s
      return detail unless detail.empty?

      Array(data["errors"]).map { |line| sentence(line) }.join("\n")
    end

    def sentence(text)
      words = text.to_s.strip
      words.end_with?(".", "!", "?") ? words : "#{words}."
    end
  end
end
