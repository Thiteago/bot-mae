module DiscordBot
  class MaeTalk
    def self.commands(bot)
      bot.command(:hey) do |event|
        prompt = event.message.content.gsub('$hey ', '')
        ollama = DiscordBot::OllamaClass.new
        response = ollama.get_response(prompt)
        if response.length > 2000
          response.scan(/.{1,2000}/m).each do |part|
            event.respond(part)
          end
        else
          event.respond(response)
        end
      end
    end
  end
end
