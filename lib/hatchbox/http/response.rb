# frozen_string_literal: true

module Hatchbox
  class Http
    class Response
      attr_reader :code, :body, :json, :headers

      def initialize(code:, body:, headers: {})
        @code = code
        @body = body
        @headers = headers
        @json = parse(body)
      end

      def ok?
        code >= 200 && code < 300
      end

      def next_page
        found = headers["link"].to_s.split(",").find { |part| part.include?("rel=\"next\"") }
        found ? found[/<([^>]+)>/, 1] : nil
      end

      private

      def parse(text)
        return nil if text.to_s.strip.empty?

        JSON.parse(text)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
