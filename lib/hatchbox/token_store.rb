# frozen_string_literal: true

module Hatchbox
  class TokenStore
    def initialize(prompt: Hatchbox::Prompt.new, store: Hatchbox::Store.new)
      @prompt = prompt
      @store = store
    end

    def path
      store.display_path
    end

    def read(env: nil)
      from_env = ENV["HATCHBOX_API_TOKEN"]
      return from_env unless Hatchbox.blank?(from_env)

      scoped = scoped(env)
      return scoped unless Hatchbox.blank?(scoped)

      blank_to_nil(store.data["token"])
    end

    def source(env: nil)
      return "the HATCHBOX_API_TOKEN environment variable" unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
      return "tokens.#{env} in #{path}" unless Hatchbox.blank?(scoped(env))
      return path unless Hatchbox.blank?(store.data["token"])

      nil
    end

    def ask
      raise Hatchbox::Error, "No terminal to ask for a token on. Set HATCHBOX_API_TOKEN instead." unless prompt.available?

      $stderr.puts("Enter your Hatchbox API token. New ones are made at https://hatchbox.io/api_tokens")
      token = prompt.secret(question: "Token: ")
      raise Hatchbox::Error, "Nothing entered." if Hatchbox.blank?(token)

      token
    end

    def ensure_token
      token = read
      return token unless Hatchbox.blank?(token)

      token = ask
      Hatchbox::Ui.action("Checking token") { verify(token) }
      save(token)
      token
    end

    def verify(token)
      probe = Hatchbox::Client.new(token: token)
      response = probe.raw(method: "GET", path: "/accounts")
      raise Hatchbox::Error, probe.error_message(response) unless response.ok?

      response.json || []
    end

    def save(token)
      store.update { |data| data["token"] = token }
    end

    def forget
      count = (Hatchbox.blank?(store.data["token"]) ? 0 : 1) + store.data.fetch("tokens", {}).length
      return 0 if count.zero?

      store.update do |data|
        data.delete("token")
        data.delete("tokens")
      end
      count
    end

    private

    attr_reader :prompt, :store

    def scoped(env)
      return nil if env.nil?

      blank_to_nil(store.data.fetch("tokens", {})[env])
    end

    def blank_to_nil(value)
      Hatchbox.blank?(value) ? nil : value
    end
  end
end
