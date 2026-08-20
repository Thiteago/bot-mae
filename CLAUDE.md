# bot-mae

Bot de Discord (Ruby puro, sem Rails) que manda DM avisando sobre pedidos de mídia do Seerr. Ver README.md para como rodar.

## Estrutura

Todo o código do bot vive em `lib/bot_mae/`. Um único processo, `bin/bot`, conecta no Discord — único lugar que instancia `Discordrb::Commands::CommandBot`, não roda em thread/worker.

A funcionalidade de tocar música em canal de voz (YouTube/Spotify, fila, DAVE/E2EE, Sidekiq/Redis, yt-dlp/ffmpeg) foi removida por não ser mais usada — ver histórico do repo se precisar entender como funcionava.

## Notificações do Seerr (pedido aprovado / disponível) via DM

`lib/bot_mae/seer_webhook_server.rb` (`DiscordBot::SeerWebhookServer`) roda um `WEBrick::HTTPServer` numa thread própria, subida por `DiscordBot::Bot#initialize` (`lib/bot_mae/bot.rb`) — só se `SEER_WEBHOOK_SECRET` estiver setado. Roda dentro do processo `bin/bot` porque só esse processo tem a instância do `Discordrb::Commands::CommandBot` — mandar DM (`bot.user(id).pm`) exige essa instância.

Duas descobertas que moldaram esse design (confirmadas lendo doc + código-fonte do Seerr, `seerr-team/seerr`, em 2026-08-13):
- O agente nativo **"Discord"** do Seerr (Settings → Notifications → Discord) nunca manda DM — só posta num canal compartilhado via webhook, usando o Discord ID cadastrado por cada usuário só pra gerar uma `@menção` dentro dessa mensagem de canal (`server/lib/notifications/agents/discord.ts`). Por isso essa feature existe: o Seerr sozinho não resolve "avisar só a pessoa que pediu, em privado".
- O agente genérico **"Webhook"** do Seerr (diferente do "Discord") já manda, no payload JSON **padrão** (sem customizar nada), o campo `request.requestedBy_settings_discordId` — o Discord ID que o usuário cadastrou na tela acima. Por causa disso, `SeerWebhookServer` **não precisa de nenhum mapeamento próprio nem de chamar a API do Seerr**: o Discord ID de quem deve receber a DM já vem pronto no payload. Se vier vazio (usuário não cadastrou o Discord ID no Seerr), só loga e ignora.

Tipos de notificação tratados: `MEDIA_APPROVED`/`MEDIA_AUTO_APPROVED` (aprovado) e `MEDIA_AVAILABLE` (disponível); qualquer outro tipo é ignorado com 200 (evita retry do Seerr). Configuração de ponta a ponta documentada no README.

**Bug corrigido: campo do Discord ID lido com nome errado (plural em vez de singular).** `SeerWebhookServer#process_notification` (`lib/bot_mae/seer_webhook_server.rb`) originalmente lia `request.requestedBy_settings_discordIds` (plural), mas o payload padrão real do Seerr (confirmado em produção, versão 3.4.1, via tela de configuração do Webhook) usa `request.requestedBy_settings_discordId` (singular — é um único ID, não uma lista). Com o nome errado, `payload.dig(...)` sempre retornava `nil` e toda notificação era silenciosamente ignorada como "Discord ID vazio", mesmo com o usuário tendo cadastrado o ID certinho no Seerr. Corrigido pra ler o campo singular e mandar a DM direto pra esse ID (sem mais tratar como array).

**Bug corrigido: DMs de "aprovado" e "disponível" chegavam com conteúdo idêntico.** `SeerWebhookServer#build_embed` (`lib/bot_mae/seer_webhook_server.rb`) só usava `payload['subject']` (título) e `payload['message']` (sinopse do TMDB) — campos que não mudam entre os tipos de notificação pro mesmo título. O `notification_type` já era lido e validado em `process_notification`, mas nunca aparecia na mensagem, então as duas DMs pareciam a mesma notificação repetida. Corrigido mapeando `notification_type` pra um rótulo em `NOTIFICATION_LABELS` (pt-BR, ex. "Pedido aprovado" / "Já disponível") setado em `embed.author`. Não usa o campo `event` que o Seerr manda no payload (também distingue os tipos) porque esse vem em inglês, sem tradução — inconsistente com o resto das mensagens do bot.
