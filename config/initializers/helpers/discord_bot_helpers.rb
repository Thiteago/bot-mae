require_relative 'youtube_search_crawler'

module DiscordBotHelpers
  include YoutubeSearchCrawler

  def recursive_queue_play(event, bot)
    user_queue = get_last_queue_cache(event)
    bot.voice_connect(event.author.voice_channel) if !bot.voice(event.server.id)
    if !user_queue.empty? && !bot.voice(event.server.id).isplaying?
      song = user_queue[0]
      youtube_dl_command = "yt-dlp -q -o - #{is_youtube_link?(song[:id]) ? song : "https://www.youtube.com/watch?v=#{song[:id]}"} | ffmpeg -i pipe:0 -f s16le -ar 48000 -ac 2 pipe:1"
      pipe = IO.popen(youtube_dl_command, 'r')

      event.respond "Tocando `#{song[:title]}`"
      bot.voice(event.server.id).play(pipe)
      shift_user_queue(event)
    end
    return Rails.cache.write('stop_playing', false) if Rails.cache.read('stop_playing')
    return recursive_queue_play(event, bot) if !get_last_queue_cache(event).empty?
    return
  end

  def is_youtube_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?youtu(be|.be)?(\.com)?\/.+/i
    return !!song.match(pattern)
  end

  def shift_user_queue(event)
    user_queue = get_last_queue_cache(event)
    user_queue.shift
    Rails.cache.write("#{event.server.id + event.author.id}_song_queue", user_queue)
  end

  def clean_queue(event)
    user_queue = Rails.cache.read("#{event.server.id + event.author.id}_song_queue")
    Rails.cache.write("#{event.server.id + event.author.id}_song_queue", [])
  end

  def is_spotify_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/.+/i
    patternPlaylist = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/playlist\/.+/i
    return !!song.match(pattern) || !!song.match(patternPlaylist)
  end

  def is_spotify_playlist_link?(song)
    pattern = /^(http(s)?:\/\/)?((w){3}.)?open.spotify.com\/playlist\/.+/i
    return song.match(pattern)
  end

  def search_song(song, user_id, server_id, is_youtube_link = false, is_spotify_link = false)
    video = nil
    if !is_youtube_link && !is_spotify_link
      video = YoutubeSearchCrawler.search_video(song, true)
      enqueue_song(video[:video_id], video[:title], user_id, server_id) if video
    elsif is_youtube_link
      if(song.include?('youtu.be'))
        song_id = song.split('be/')[1]
      else
        song_id = song.split('v=')[1]
      end
      video_title = YoutubeSearchCrawler.get_video_title(song)
      enqueue_song(song_id, video_title, user_id, server_id)
    elsif is_spotify_link
      if is_spotify_playlist_link?(song)
        playlist = RSpotify::Playlist.find_by_id(song.split('playlist/')[1])
        tracks = playlist.tracks.map do |track|
          {name: track.name, artist: track.artists.first.name}
        end

        if Rails.cache.read("#{server_id + user_id}_song_queue").empty?
          video = YoutubeSearchCrawler.search_video(tracks[0][:name] + " " + tracks[0][:artist], true)
          enqueue_song(video[:video_id], video[:title], user_id, server_id) if video
        end
        tracks.shift
        Thread.new do
          tracks = YoutubeSearchCrawler.search_video_by_playlist(tracks, user_id, server_id)
        end

      else
        track = RSpotify::Track.find(song.split('track/')[1])
        video = YoutubeSearchCrawler.search_video(track.name + " " + track.artists.first.name, true)
        enqueue_song(video[:video_id],video[:title], user_id, server_id) if video
      end
    end
    return video
  end

  def find_songs(song,event)
    result = nil
    original_queue_size = Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size
    if is_youtube_link?(song)
      result = search_song(song, event.author.id, event.server.id, true)
      if !result.nil?
        if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size && original_queue_size > 0
          event.respond "Coloquei `#{result[:title]}` na lista patrão!"
        end
      end
    elsif is_spotify_link?(song)
      result = search_song(song, event.author.id, event.server.id, false, true)
      if !result.nil?
        if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size && original_queue_size > 0
          event.respond "Coloquei `#{result[:title]}` na lista patrão!"
        end
      end
    else
      song = event.message.content.gsub('$toca', "music")
      result = search_song(song, event.author.id, event.server.id)
      if !result.nil?
        if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size && original_queue_size > 0
          event.respond "Coloquei `#{result[:title]}` na lista patrão!"
        end
      end
    end
  end

  def enqueue_song(video_id, video_title, user_id, server_id)
    user_queue = Rails.cache.read("#{server_id + user_id}_song_queue")
    user_queue << {id: video_id, title: video_title}
    Rails.cache.write("#{server_id + user_id}_song_queue", user_queue)
  end

  def get_last_queue_cache(event)
    queue = Rails.cache.read("#{event.server.id + event.author.id}_song_queue")
    queue.nil? ? [] : queue
  end

  def create_queue_embed(user_queue, requested_page=1)
    embed = Discordrb::Webhooks::Embed.new
    embed.title = "Fila de músicas - Página #{requested_page}"
    embed.description = ""
    page = requested_page.to_i
    page = 1 if page == 0
    start_index = (page - 1) * 10
    end_index = start_index + 10
    user_queue[start_index..end_index].each_with_index do |song, index|
      link = is_youtube_link?(song[:id]) ? song : "https://www.youtube.com/watch?v=#{song[:id]}"
      embed.description += "#{start_index + index + 1}. [#{song[:title]}](#{link})\n"
    end
    embed.color = 0xeb237d
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Página #{requested_page} de #{(user_queue.size / 10.0).ceil}")
    embed
  end

end
