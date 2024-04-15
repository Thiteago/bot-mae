module DiscordBotHelpers
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

    recursive_queue_play(event, bot) if !get_last_queue_cache(event).empty?
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
    if !is_youtube_link && !is_spotify_link
      videos = Yt::Collections::Videos.new
      video = videos.where(q: song, order: 'relevance').first
      enqueue_song(video.id,video.title, user_id, server_id) if video
    elsif is_youtube_link
      if(song.include?('youtu.be'))
        song_id = song.split('be/')[1]
      else
        song_id = song.split('v=')[1]
      end
      video = Yt::Video.new id: song_id
      enqueue_song(video.id,video.title, user_id, server_id) if video
    elsif is_spotify_link
      if is_spotify_playlist_link?(song)
        playlist = RSpotify::Playlist.find_by_id(song.split('playlist/')[1])
        tracks = playlist.tracks.map do |track|
          {name: track.name, artist: track.artists.first.name}
        end
        download_thread = Thread.new do
          tracks.each do |track|
            videos = Yt::Collections::Videos.new
            video = videos.where(q: track[:name] + " " + track[:artist], order: 'relevance').first
            puts video
            enqueue_song(video.id,video.title, user_id, server_id) if video
          end
        end
        download_thread.join
      else
        track = RSpotify::Track.find(song.split('track/')[1])
        videos = Yt::Collections::Videos.new
        video = videos.where(q: track.name, order: 'relevance').first
        enqueue_song(video.id,video.title, user_id, server_id) if video
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
          event.respond "Coloquei `#{result.title}` na lista patrão!"
        end
      end
    elsif is_spotify_link?(song)
      result = search_song(song, event.author.id, event.server.id, false, true)
      if !result.nil?
        if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size
          event.respond "Coloquei essa ai na lista patrão!"
        end
      end
    else
      song = event.message.content.gsub('$toca', "music")
      result = search_song(song, event.author.id, event.server.id)
      if !result.nil?
        if Rails.cache.read("#{event.server.id + event.author.id}_song_queue").size > original_queue_size
          event.respond "Coloquei essa ai na lista patrão!"
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

end
