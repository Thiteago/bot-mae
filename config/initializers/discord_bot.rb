require 'discordrb'
require 'rspotify'
require 'yt'

class DiscordBot
  OUTPUT_FOLDER = "tmp/songs"

  def initialize
    setup_apis
    @stop_thread = false

    bot = Discordrb::Commands::CommandBot.new token: ENV.fetch('DISCORD_BOT_TOKEN'), client_id: ENV.fetch('DISCORD_BOT_CLIENT_ID'), prefix: '$'
    define_commands(bot)
    bot_thread = Thread.new { bot.run }
  end

  private
  def define_commands(bot)
    bot.command(:toca) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      result = nil
      requested_song = event.message.content.gsub('$toca ', '')

      Rails.cache.write("#{event.server.id + event.author.id}_song_queue", []) if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").nil?
      find_songs(requested_song,event)
      user_queue = Rails.cache.read("#{event.server.id + event.author.id}_song_queue")

      if !user_queue.empty?
        recursive_queue_play(event, bot)
        ""
      elsif is_youtube_link?(requested_song) || is_spotify_link?(requested_song)
        "Esse link ai ta esquisito hein, compreendi nao."
      else
        "Não encontrei esse negócio não, voce disse #{requested_song} mesmo?"
      end
    end

    bot.command(:convite) do |event|
      "https://discord.com/oauth2/authorize?client_id=#{ENV.fetch('DISCORD_BOT_CLIENT_ID')}&scope=bot&permissions=8"
    end

    bot.command(:ajuda) do |event|
      msg = <<~HEREDOC

      **Comandos disponíveis:**
      - `$toca <nome da música>`: Toca uma música no canal de voz que você está.
      - `$para_de_toca`: Para de tocar a música que está tocando.
      - `$sai_daqui`: Sai do canal de voz.
      - `$convite`: Retorna o link de convite do bot.
      - `$ajuda`: Exibe essa mensagem.

      HEREDOC
      msg
    end

    bot.command(:para_de_toca) do |event|
      return "Faça me o favor de entrar em uma sala de áudio pra eu poder fazer alguma coisa." if event.author.voice_channel == nil
      event.voice.stop_playing
      clean_queue(event)
      "To parando já, nao me enche!"
    end

    bot.command(:sai_daqui) do |event|
      return "Vem pra dentro da sala pra me tirar por gentileza " if event.author.voice_channel == nil
      event.voice.play_file("lib/assets/sounds/tchau.mp3")
      bot.voice_destroy(event.server.id)
      "To saindo, mas se me chamar de novo eu nao volto!"
    end

    bot.command(:default) do |event|
      "Comando não encontrado"
    end
  end

  def recursive_queue_play(event, bot)
    user_queue = Rails.cache.read("#{event.server.id + event.author.id}_song_queue")
    sleep(1) if !user_queue.empty?
    puts "Queue: #{user_queue}"
    bot.voice_connect(event.author.voice_channel) if !bot.voice(event.server.id)
    if !user_queue.empty?
      song = user_queue[0]
      Rails.cache.write("#{event.server.id + event.author.id}_song_queue", user_queue)
      begin
        if !File.exist?("#{OUTPUT_FOLDER}/#{song[:path]}.mp3")
          sleep(1)
          if(!File.exist?("#{OUTPUT_FOLDER}/#{song[:path]}.mp3"))
            user_queue.shift
            Rails.cache.write("#{event.server.id + event.author.id}_song_queue", user_queue)
            return recursive_queue_play(event, bot)
          end
        end

        if !bot.voice(event.server.id).isplaying?
          event.respond "Tocando `#{song[:title]}`"
          event.voice.play_file("#{OUTPUT_FOLDER}/#{song[:path]}.mp3")
          user_queue.pop
          File.delete("#{OUTPUT_FOLDER}/#{song[:path]}.mp3")
        end
        recursive_queue_play(event, bot)
      rescue
        event.voice.stop_playing
        return event.respond "Deu ruim, nao consegui tocar a música."
      end
      return if user_queue.empty? && !bot.voice(event.server.id).isplaying?

      recursive_queue_play(event, bot)
    end
  end

  def is_youtube_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?youtu(be|.be)?(\.com)?\/.+/i
    return !!song.match(pattern)
  end

  def clean_queue(event)
    user_queue = Rails.cache.read("#{event.server.id + event.author.id}_song_queue")
    user_queue.each do |song|
      File.delete("#{OUTPUT_FOLDER}/#{song[:path]}.mp3")
    end
    Rails.cache.write("#{event.server.id + event.author.id}_song_queue", [])
  end

  def is_spotify_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/.+/i
    return !!song.match(pattern)
  end

  def is_spotify_playlist_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/playlist\/.+/i
    return song.match(pattern)
  end

  def search_song(song, user_id, server_id, is_youtube_link = false, is_spotify_link = false)
    if !is_youtube_link && !is_spotify_link
      videos = Yt::Collections::Videos.new
      video = videos.where(q: song, order: 'relevance').first
      enqueue_song(video.id,video.title, user_id, server_id)
    elsif is_youtube_link
      video = Yt::Video.new id: song.split('v=')[1]
      enqueue_song(video.id,video.title, user_id, server_id)
    elsif is_spotify_link
      if is_spotify_playlist_link?(song)
        playlist = RSpotify::Playlist.find_by_id(song.split('playlist/')[1])
        tracks = playlist.tracks.map(&:name)
        download_thread = Thread.new do
          while !@stop_thread do
            tracks.each do |track|
              videos = Yt::Collections::Videos.new
              video = videos.where(q: track, order: 'relevance').first
              enqueue_song(video.id,video.title, user_id, server_id)
            end
          end
        end
      else
        track = RSpotify::Track.find(song.split('track/')[1])
      end
    end
    return video
  end

  def find_songs(song,event)
    original_queue_size = Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size
    if is_youtube_link?(song)
      search_song(song, event.author.id, event.server.id, true)
      event.respond "Coloquei essa ai na lista patrão!" if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size
    elsif is_spotify_link?(song)
      search_song(song, event.author.id, event.server.id, false, true)
      event.respond "Coloquei essa ai na lista patrão!" if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size
    else
      song = event.message.content.gsub('$toca', "music")
      search_song(song, event.author.id, event.server.id)
      event.respond "Coloquei essa ai na lista patrão!" if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size
    end
  end

  def download_song(video_id, video_title, user_id, server_id)
    random_number = Time.now.to_i
    system("yt-dlp --extract-audio --audio-format mp3 -o '#{OUTPUT_FOLDER}/output_#{random_number}_#{user_id}_#{server_id}.mp3' https://www.youtube.com/watch?v=#{video_id}")
    return {title: video_title, path: "output_#{random_number}_#{user_id}_#{server_id}"}
  end

  def enqueue_song(video_id, video_title, user_id, server_id)
    user_queue = Rails.cache.read("#{server_id + user_id}_song_queue")
    user_queue << download_song(video_id, video_title, user_id, server_id)
    Rails.cache.write("#{server_id + user_id}_song_queue", user_queue)
  end

  def setup_apis
    Yt.configure do |config|
      config.api_key = ENV.fetch('GOOGLE_API_KEY')
    end

    RSpotify.authenticate(ENV.fetch('SPOTIFY_CLIENT_ID'), ENV.fetch('SPOTIFY_CLIENT_SECRET'))
  end
end

DiscordBot.new
