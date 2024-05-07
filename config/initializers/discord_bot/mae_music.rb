module DiscordBot
  class MaeMusic
    def self.commands(bot)
      bot.command(:toca) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        helper = DiscordBot::Helpers.new(
          user_id: event.author.id,
          server_id: event.server.id,
          voice_channel_id: event.author.voice_channel.id,
          requested_song: event.message.content.gsub('$toca ', ''),
          user_queue: "#{event.server.id}_#{event.author.voice_channel.id}_server_queue",
          event: event,
          bot: bot,
        )

        user_queue = self.initialize_queue(helper.details[:server_id], helper.details[:voice_channel_id])
        self.resume_playing(helper, event, bot)

        helper.find_songs
        queue = Rails.cache.read(helper.details[:user_queue])

        if !queue.empty?
          helper.recursive_queue_play
          ""
        elsif helper.details[:platform] == 'not_identified'
          "Esse link ai ta esquisito hein, compreendi nao."
        else
          "Não encontrei esse negócio não, voce disse `#{helper.details[:requested_song]}` mesmo?"
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
        Rails.cache.write("stop_playing_#{event.server.id}_#{event.author.voice_channel.id}", true)
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
        user_queue = Rails.cache.read("#{event.server.id}_#{event.author.voice_channel.id}_server_queue")
        user_queue.shuffle!
        Rails.cache.write("#{event.server.id}_#{event.author.voice_channel.id}_server_queue", user_queue)
        "Prontinho, fila embaralhada!"
      end

      bot.command(:fila) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        requested_page = event.message.content.gsub('$fila ', '')
        requested_page = 1 if requested_page == "$fila"
        user_queue = Rails.cache.read("#{event.server.id}_#{event.author.voice_channel.id}_server_queue")
        return "Fila vazia, manda mais música ai!" if user_queue.empty?
        helper = DiscordBot::Helpers.new(
          user_id: event.author.id,
          server_id: event.server.id,
          voice_channel_id: event.author.voice_channel.id,
          requested_song: event.message.content.gsub('$toca ', ''),
          user_queue: "#{event.server.id}_#{event.author.voice_channel.id}_server_queue",
          event: event,
          bot: bot,
        )
        embed = helper.create_queue_embed(user_queue, requested_page)
        event.channel.send_embed("", embed)
      end

      bot.command(:pula) do |event|
        return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
        event.voice.stop_playing
        if !Rails.cache.read("#{event.server.id}_#{event.author.voice_channel.id}_server_queue").empty? && Rails.cache.read("#{event.server.id}_#{event.author.voice_channel.id}_server_queue").size > 1
          "Pulando a música atual!"
        else
          "Não tem mais música pra tocar, então não tem o que pular, vou é parar 🦥."
        end
      end
    end

  private
    def self.initialize_queue(server_id, voice_channel_id)
      queue = Rails.cache.read("#{server_id}_#{voice_channel_id}_server_queue")

      if queue.nil?
        queue = Rails.cache.fetch("#{server_id}_#{voice_channel_id}_server_queue") do
          []
        end
      end
      queue
    end

    def self.resume_playing(helper, event, bot)
      queue = Rails.cache.read(helper.details[:user_queue])
      if(helper.details[:requested_song] == "" || helper.details[:requested_song] == "$toca" && queue.empty?)
        return "Voce precisa me dizer qual música quer ouvir, nao sou adivinho!"
      elsif helper.details[:requested_song] == "" || helper.details[:requested_song] == "$toca" && !queue.empty?
        event.respond "Vorteno a tocar!"
        if(bot.voices.key?(event.server.id))
          event.voice.continue
        else
          helper.recursive_queue_play
        end
        return ""
      end
    end

  end
end
