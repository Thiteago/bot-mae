require 'ollama-ai'

module DiscordBot
  class OllamaClass
    def initialize
      @ollama = Ollama.new(
        credentials: {
          address: 'http://localhost:11434',
          options: {
            server_sent_events: true
          }
        }
      )
    end

    def get_response(message)
      res = @ollama.generate(
        {
          model: 'llama3',
          prompt: message,
          stream: false
        }
      )
      res[0]["response"]
    end
  end
end
