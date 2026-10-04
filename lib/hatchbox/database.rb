# frozen_string_literal: true

module Hatchbox
  class Database
    def initialize(text)
      @uri = URI.parse(text)
    rescue URI::InvalidURIError
      raise Hatchbox::Error, "Could not read the connection URI Hatchbox returned."
    end

    def user
      decode(uri.user)
    end

    def password
      decode(uri.password)
    end

    def host
      uri.host.to_s
    end

    def port
      (uri.port || default_port).to_s
    end

    def name
      decode(uri.path.to_s.sub(%r{\A/}, ""))
    end

    def sslmode
      found = URI.decode_www_form(uri.query.to_s).to_h["sslmode"]
      Hatchbox.blank?(found) ? "prefer" : found
    end

    def scheme
      uri.scheme.to_s
    end

    private

    attr_reader :uri

    def default_port
      return 6379 if scheme.start_with?("redis")
      return 3306 if scheme.start_with?("mysql")

      5432
    end

    def decode(value)
      value.nil? ? "" : URI.decode_www_form_component(value)
    end
  end
end
