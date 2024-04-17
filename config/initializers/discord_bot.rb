require 'discordrb'
require 'rspotify'
require 'yt'
require_relative 'helpers/discord_bot_helpers'

class DiscordBot
  include DiscordBotHelpers
  OUTPUT_FOLDER = "tmp/songs"
  $running_threads = []

  def initialize
    setup_apis

    bot = Discordrb::Commands::CommandBot.new token: ENV.fetch('DISCORD_BOT_TOKEN'), client_id: ENV.fetch('DISCORD_BOT_CLIENT_ID'), prefix: '$'
    define_commands(bot)
    bot_thread = Thread.new { bot.run }
  end

  private
  def define_commands(bot)
    bot.command(:toca) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      requested_song = event.message.content.gsub('$toca ', '')

      if(requested_song == "" || requested_song == "$toca" && Rails.cache.read("#{event.server.id + event.author.id}_song_queue").empty?)
        return "Voce precisa me dizer qual música quer ouvir, nao sou adivinho!"
      elsif requested_song == "" || requested_song == "$toca" && !Rails.cache.read("#{event.server.id + event.author.id}_song_queue").empty?
        event.respond "Vorteno a tocar!"
        bot.voice_connect(event.author.voice_channel)
        bot.voice(event.server.id).playing? ? event.voice.continue : recursive_queue_play(event, bot)
        return ""
      end

      Rails.cache.fetch("#{event.server.id + event.author.id}_song_queue") do
        []
      end

      find_songs(requested_song, event)
      user_queue = Rails.cache.read("#{event.server.id + event.author.id}_song_queue")

      if !user_queue.empty?
        Thread.new do
          recursive_queue_play(event, bot)
        end
        ""
      elsif is_youtube_link?(requested_song) || is_spotify_link?(requested_song)
        "Esse link ai ta esquisito hein, compreendi nao."
      else
        "Não encontrei esse negócio não, voce disse `#{requested_song}` mesmo?"
      end
    end

    bot.command(:convite) do |event|
      "https://discord.com/oauth2/authorize?client_id=#{ENV.fetch('DISCORD_BOT_CLIENT_ID')}&scope=bot&permissions=8"
    end

    bot.command(:ajuda) do |event|
      msg = <<~HEREDOC

      **Comandos disponíveis:**
      - `$toca <nome da música>`: Toca uma música no canal de voz que você está.
      - `$toca`: Retorna a tocar a musica que esta em fila.
      - `$para_de_toca`: Para de tocar a música que está tocando.
      - `$sai_daqui`: Sai do canal de voz.
      - `$convite`: Retorna o link de convite do bot.
      - `$ajuda`: Exibe essa mensagem.
      - `$pula`: Pula a música atual.
      - `$fila`: Exibe a fila de músicas.
      - `$limpa_fila`: Limpa a fila de músicas.
      - `$pausa_pofavo`: Pausa a música que está tocando.

      HEREDOC
      msg
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
      clean_queue(event)
      "To parando já, nao me enche, e também apaguei a fila!"
    end

    bot.command(:limpa_fila) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      clean_queue(event)
      "Fila limpa, pode pedir mais músicas!"
    end

    bot.command(:sai_daqui) do |event|
      return "Vem pra dentro da sala pra me tirar por gentileza " if event.author.voice_channel == nil
      event.voice.play_file("lib/assets/sounds/tchau.mp3")
      bot.voice_destroy(event.server.id)
      "To saindo, mas se me chamar de novo eu nao volto!"
    end

    bot.command(:mistura) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      user_queue = get_last_queue_cache(event)
      user_queue.shuffle!
      Rails.cache.write("#{event.server.id + event.author.id}_song_queue", user_queue)
      "Prontinho, fila embaralhada!"
    end

    bot.command(:fila) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      requested_page = event.message.content.gsub('$fila ', '')
      requested_page = 1 if requested_page == "$fila"
      user_queue = get_last_queue_cache(event)
      return "Fila vazia, manda mais música ai!" if user_queue.empty?
      embed = create_queue_embed(user_queue, requested_page)
      event.channel.send_embed("", embed)
    end

    bot.command(:pula) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      event.voice.stop_playing
      if !get_last_queue_cache(event).empty? && get_last_queue_cache(event).size > 1
        "Pulando a música atual!"
      else
        "Não tem mais música pra tocar, então não tem o que pular, vou é parar 🦥."
      end
    end

    bot.command(:default) do |event|
      "Comando não encontrado"
    end
  end

  def setup_apis
    Yt.configure do |config|
      config.api_key = ENV.fetch('GOOGLE_API_KEY')
    end

    RSpotify.authenticate(ENV.fetch('SPOTIFY_CLIENT_ID'), ENV.fetch('SPOTIFY_CLIENT_SECRET'))
  end
end

DiscordBot.new
