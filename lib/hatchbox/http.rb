# frozen_string_literal: true

module Hatchbox
  class Http
    def initialize(base:, token:)
      @base = base
      @token = token
    end

    def request(method:, path:, body: nil)
      uri = URI.parse(path.start_with?("http://", "https://") ? path : "#{base}#{path}")
      response = perform(uri: uri, message: build(method: method, uri: uri, body: body))
      Hatchbox::Http::Response.new(code: response.code.to_i, body: response.body.to_s, headers: response.each_header.to_h)
    end

    private

    attr_reader :base, :token

    def build(method:, uri:, body:)
      message = Net::HTTP.const_get(method.capitalize).new(uri.request_uri)
      message["Authorization"] = "Bearer #{token}"
      message["Accept"] = "application/json"
      message["User-Agent"] = Hatchbox.platform
      if body
        message["Content-Type"] = "application/json"
        message.body = JSON.dump(body)
      end
      message
    end

    def perform(uri:, message:)
      session(uri).request(message)
    rescue StandardError => e
      drop(uri)
      raise Hatchbox::Error, "Could not reach #{uri.host}: #{e.message}"
    end

    def session(uri)
      pool = (Thread.current[:hatchbox_sessions] ||= {})
      key = pool_key(uri)
      open = pool[key]
      return open if open && open.started?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 15
      http.read_timeout = 90
      http.start
      pool[key] = http
    end

    def drop(uri)
      pool = Thread.current[:hatchbox_sessions] || {}
      open = pool.delete(pool_key(uri))
      open.finish if open && open.started?
    rescue StandardError
      nil
    end

    def pool_key(uri)
      "#{uri.scheme}://#{uri.host}:#{uri.port}"
    end
  end
end
