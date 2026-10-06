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

    def read
      found = first_set
      found ? found.last : nil
    end

    def source
      found = first_set
      found ? found.first : nil
    end

    def ask
      raise Hatchbox::Error, "No terminal to ask for a token on. Set HATCHBOX_API_TOKEN instead." unless prompt.available?

      $stderr.puts("Enter your Hatchbox API token. Make one at https://hatchbox.io/api_tokens")
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
      Hatchbox::Client.new(token: token).get("/accounts").json || []
    end

    def save(token)
      store.update { |data| data["token"] = token }
    end

    def forget
      return if Hatchbox.blank?(store.data["token"])

      store.update { |data| data.delete("token") }
    end

    private

    attr_reader :prompt, :store

    def first_set
      return ["the HATCHBOX_API_TOKEN environment variable", ENV["HATCHBOX_API_TOKEN"]] unless Hatchbox.blank?(ENV["HATCHBOX_API_TOKEN"])
      return [path, store.data["token"]] unless Hatchbox.blank?(store.data["token"])

      nil
    end
  end
end
