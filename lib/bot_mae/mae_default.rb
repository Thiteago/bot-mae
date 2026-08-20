module DiscordBot
  class MaeDefault
    def self.commands(bot)
      bot.command(:convite) do |event|
        "https://discord.com/oauth2/authorize?client_id=#{ENV.fetch('DISCORD_BOT_CLIENT_ID')}&scope=bot&permissions=8"
      end

      bot.command(:ajuda) do |event|
        msg = <<~HEREDOC

        **Comandos disponíveis:**
        - `$convite`: Retorna o link de convite do bot.
        - `$ajuda`: Exibe essa mensagem.

        HEREDOC
        msg
      end

      bot.command(:default) do |event|
        "Comando não encontrado"
      end
    end
  end
end
