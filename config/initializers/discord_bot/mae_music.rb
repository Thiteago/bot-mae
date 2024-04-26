module DiscordBot
  class MaeMusic
    def self.commands(bot)
      bot.command(:toca) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        requested_song = event.message.content.gsub('$toca ', '')
        queue = Rails.cache.read("#{event.server.id}_song_queue")

        if queue.nil?
          queue = Rails.cache.fetch("#{event.server.id}_song_queue") do
            []
          end
        end

        if(requested_song == "" || requested_song == "$toca" && queue.empty?)
          return "Voce precisa me dizer qual música quer ouvir, nao sou adivinho!"
        elsif requested_song == "" || requested_song == "$toca" && !queue.empty?
          event.respond "Vorteno a tocar!"
          bot.voice_connect(event.author.voice_channel)
          bot.voice(event.server.id).playing? ? event.voice.continue : DiscordBot::Helpers.recursive_queue_play(event, bot)
          return ""
        end

        DiscordBot::Helpers.find_songs(requested_song, event)
        user_queue = Rails.cache.read("#{event.server.id}_song_queue")

        if !user_queue.empty?
          thread = Thread.new do
            DiscordBot::Helpers.recursive_queue_play(event, bot)
          end
          $running_threads << thread
          ""
        elsif DiscordBot::Helpers.is_youtube_link?(requested_song) || DiscordBot::Helpers.is_spotify_link?(requested_song)
          "Esse link ai ta esquisito hein, compreendi nao."
        else
          "Não encontrei esse negócio não, voce disse `#{requested_song}` mesmo?"
        end
      end

      bot.command(:pausa_pofavo) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        event.voice.pause
        "Pausado, se quiser continuar é só mandar um `$toca`!"
      end

      bot.command(:para_de_toca) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        event.voice.stop_playing
        Rails.cache.write('stop_playing', true)
        DiscordBot::Helpers.clean_queue(event)
        "To parando já, nao me enche, e também apaguei a fila!"
      end

      bot.command(:limpa_fila) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        DiscordBot::Helpers.clean_queue(event)
        "Fila limpa, pode pedir mais músicas!"
      end

      bot.command(:mistura) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        user_queue = DiscordBot::Helpers.get_last_queue_cache(event)
        user_queue.shuffle!
        Rails.cache.write("#{event.server.id}_song_queue", user_queue)
        "Prontinho, fila embaralhada!"
      end

      bot.command(:fila) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        requested_page = event.message.content.gsub('$fila ', '')
        requested_page = 1 if requested_page == "$fila"
        user_queue = DiscordBot::Helpers.get_last_queue_cache(event)
        return "Fila vazia, manda mais música ai!" if user_queue.empty?
        embed = DiscordBot::Helpers.create_queue_embed(user_queue, requested_page)
        event.channel.send_embed("", embed)
      end

      bot.command(:pula) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        event.voice.stop_playing
        if !DiscordBot::Helpers.get_last_queue_cache(event).empty? && DiscordBot::Helpers.get_last_queue_cache(event).size > 1
          "Pulando a música atual!"
        else
          "Não tem mais música pra tocar, então não tem o que pular, vou é parar 🦥."
        end
      end
    end
  end
end
