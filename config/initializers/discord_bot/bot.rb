require 'discordrb'
require 'rspotify'
require_relative 'mae_music'

module DiscordBot
  class Bot
    OUTPUT_FOLDER = "tmp/songs"
    $running_threads = []

    def initialize
      setup_apis

      bot = Discordrb::Commands::CommandBot.new token: ENV.fetch('DISCORD_BOT_TOKEN'), client_id: ENV.fetch('DISCORD_BOT_CLIENT_ID'), prefix: '$'
      define_commands(bot)
      DiscordBot::MaeMusic.commands(bot)
      bot_thread = Thread.new { bot.run }
    end

    private
    def define_commands(bot)
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

      bot.command(:sai_daqui) do |event|
        return "Vem pra dentro da sala pra me tirar por gentileza " if event.author.voice_channel == nil
        Rails.cache.write('stop_playing', true)
        $running_threads.each do |thread|
          thread.kill
        end
        event.voice.play_file("lib/assets/sounds/tchau.mp3")
        bot.voice_destroy(event.server.id)
        "To saindo, mas se me chamar de novo eu nao volto!"
      end

      bot.command(:default) do |event|
        "Comando não encontrado"
      end
    end

    def setup_apis
      RSpotify.authenticate(ENV.fetch('SPOTIFY_CLIENT_ID'), ENV.fetch('SPOTIFY_CLIENT_SECRET'))
    end
  end
end

DiscordBot::Bot.new
