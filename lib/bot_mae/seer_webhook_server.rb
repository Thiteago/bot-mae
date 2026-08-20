require 'webrick'
require 'json'

module DiscordBot
  class SeerWebhookServer
    NOTIFICATION_TYPES = %w[MEDIA_APPROVED MEDIA_AUTO_APPROVED MEDIA_AVAILABLE].freeze
    NOTIFICATION_LABELS = {
      'MEDIA_APPROVED' => 'Pedido aprovado',
      'MEDIA_AUTO_APPROVED' => 'Pedido aprovado automaticamente',
      'MEDIA_AVAILABLE' => 'Já disponível'
    }.freeze

    def initialize(bot)
      @bot = bot
      @port = ENV.fetch('SEER_WEBHOOK_PORT', '8090').to_i
      @secret = ENV.fetch('SEER_WEBHOOK_SECRET')
    end

    def start
      server = WEBrick::HTTPServer.new(Port: @port, Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      server.mount_proc('/webhooks/seer') { |req, res| handle(req, res) }
      trap('INT') { server.shutdown }
      log("Servidor de webhooks do Seerr escutando na porta #{@port}")
      server.start
    end

    private

    def handle(req, res)
      unless req.request_method == 'POST'
        res.status = 404
        return
      end

      unless req['Authorization'] == @secret
        res.status = 401
        res.body = 'unauthorized'
        return
      end

      payload = JSON.parse(req.body || '{}')
      process_notification(payload)
      res.status = 200
      res.body = 'ok'
    rescue JSON::ParserError
      res.status = 400
      res.body = 'invalid json'
    end

    def process_notification(payload)
      return unless NOTIFICATION_TYPES.include?(payload['notification_type'])

      discord_id = payload.dig('request', 'requestedBy_settings_discordId')
      if discord_id.nil? || discord_id.empty?
        log("Notificação #{payload['notification_type']} ignorada: requestedBy_settings_discordId vazio (usuário não cadastrou o Discord ID no Seerr)")
        return
      end

      send_dm(discord_id, build_embed(payload))
    end

    def send_dm(discord_id, embed)
      user = @bot.user(discord_id)
      unless user
        log("Não encontrei o usuário do Discord #{discord_id} pra mandar a notificação do Seerr")
        return
      end

      user.pm.send_embed('', embed)
    rescue StandardError => e
      log("Falha ao mandar DM do Seerr pro usuário #{discord_id}: #{e.class}: #{e.message}")
    end

    def build_embed(payload)
      embed = Discordrb::Webhooks::Embed.new
      embed.author = Discordrb::Webhooks::EmbedAuthor.new(name: NOTIFICATION_LABELS[payload['notification_type']])
      embed.title = payload['subject']
      embed.description = payload['message']
      embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: payload['image']) if payload['image']
      embed.color = 0xeb237d
      embed
    end

    def log(message)
      if defined?(Discordrb::LOGGER)
        Discordrb::LOGGER.info(message)
      else
        warn(message)
      end
    end
  end
end
