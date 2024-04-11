require 'discordrb'
require 'yt'

class DiscordBot
  def initialize
    Yt.configure do |config|
      config.api_key = ENV.fetch('GOOGLE_API_KEY')
    end

    bot = Discordrb::Commands::CommandBot.new token: ENV.fetch('DISCORD_BOT_TOKEN'), client_id: ENV.fetch('DISCORD_BOT_CLIENT_ID'), prefix: '$'
    define_commands(bot)
    bot.run
  end

  private
  def define_commands(bot)
    bot.command(:toca) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      song = event.message.content.split(' ')[1]
      result = search_song(song, is_youtube_link?(song))
      if result != nil
        random_number = Time.now.to_i
        output_folder = "tmp/songs"
        system("yt-dlp --extract-audio --audio-format mp3 -o '#{output_folder}/output_#{random_number}.mp3' https://www.youtube.com/watch?v=#{result.id}")
        bot.voice_connect(event.author.voice_channel)
        event.respond "Tocando `#{result.title}`"
        event.voice.play_file("#{output_folder}/output_#{random_number}.mp3")
        File.delete("#{output_folder}/output_#{random_number}.mp3")
        ""
      else
        "Não encontrei esse negócio não, voce disse #{song} mesmo?"
      end
    end

    bot.command(:para_de_toca) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      event.voice.stop_playing
      bot.voice_destroy(event.server.id)
      "To parando já, nao me enche!"
    end


    bot.command(:default) do |event|
      "Comando não encontrado"
    end
  end

  def is_youtube_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?youtu(be|.be)?(\.com)?\/.+/i
    return song.match(pattern)
  end

  def search_song(song, is_youtube_link = false)
    if !is_youtube_link
      videos = Yt::Collections::Videos.new
      video = videos.where(q: song, order: 'relevance').first
    else
      video = Yt::Video.new id: song.split('v=')[1]
    end
    return video
  end
end

DiscordBot.new
