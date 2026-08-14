# Discord Bot Mãe

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Description

Bot de Discord (Ruby puro, sem framework web) que toca música em canais de voz: busca no YouTube, playlists/álbuns/faixas do Spotify, fila por canal de voz, pular/pausar/embaralhar.

## Rodando com Docker (recomendado)

1. Copie `.env.example` para `.env` e preencha:
   - `DISCORD_BOT_TOKEN` / `DISCORD_BOT_CLIENT_ID`: criados em https://discord.com/developers/applications
   - `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET`: criados em https://developer.spotify.com/dashboard
   - `YOUTUBE_API_KEY`: crie um projeto em https://console.cloud.google.com, ative a "YouTube Data API v3" e gere uma API key. A cota gratuita padrão é 10.000 unidades/dia (cada busca custa 100, ~100 buscas/dia de graça — suficiente pra uso pessoal).
2. Crie o arquivo de cookies (usado pelo `yt-dlp`; o `docker-compose.yml` sempre monta `./cookies.txt` no container em leitura e escrita, então o arquivo precisa existir mesmo que vazio — e precisa ser gravável pelo container, cujo usuário roda com uid 1000, que raramente é o mesmo uid do seu usuário no host):

   ```bash
   touch cookies.txt
   chmod 666 cookies.txt
   ```

   Se o YouTube começar a bloquear o bot (erro `429 Too Many Requests` / `Sign in to confirm you're not a bot`), preencha esse arquivo com cookies de uma conta Google logada, exportados no formato Netscape usando uma extensão como [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc) (Chrome/Firefox) direto de `youtube.com`. Reinicie os containers (`docker compose restart bot worker`) depois de atualizar o arquivo.

3. Suba tudo:

   ```bash
   docker compose up --build
   ```

   Isso inicia três serviços: `redis` (fila/estado), `bot` (conexão com o Discord) e `worker` (Sidekiq, processa playlists do Spotify em background).

4. Convide o bot pro seu servidor usando o comando `$convite` (ou monte o link manualmente com o `DISCORD_BOT_CLIENT_ID`).

## Rodando sem Docker

Requer Ruby 3.4.1 (ver `.ruby-version`), Redis rodando localmente, e os binários `ffmpeg` e `yt-dlp` no PATH.

```bash
bundle install
bin/bot      # processo do bot (conecta no Discord)
bin/worker   # processo do Sidekiq, em outro terminal
```

Se precisar de cookies pro `yt-dlp` (ver passo 2 da seção com Docker), aponte a env var `YTDLP_COOKIES_FILE` pro caminho do arquivo antes de rodar — não precisa existir se não for usar.

## Notificações do Seerr (pedido aprovado / disponível)

O bot pode mandar uma DM pro usuário do Discord que fez o pedido no [Seerr](https://github.com/seerr-team/seerr) quando o pedido é aprovado e quando fica disponível. É opcional: se você não configurar `SEER_WEBHOOK_SECRET`, essa parte do bot simplesmente não sobe.

1. No `.env` do bot-mae, preencha:
   - `SEER_WEBHOOK_SECRET`: um valor secreto qualquer, inventado por você (vai validar que a chamada realmente veio do seu Seerr).
   - `SEER_WEBHOOK_PORT` (opcional, default `8090`): porta onde o bot escuta o webhook.
2. No Seerr, cada usuário que quiser receber a DM precisa cadastrar o próprio Discord ID em **Settings → Notifications → Discord** da conta dele (não precisa marcar nenhum tipo de notificação nessa tela — aquilo ali é só usado pelo agente "Discord" nativo do Seerr, que manda menção num canal compartilhado, não DM).
3. No Seerr (como admin), vá em **Settings → Notifications → Webhook** (não é o agente "Discord"):
   - Webhook URL: `http://<host-do-bot>:8090/webhooks/seer` (ajuste a porta se você mudou `SEER_WEBHOOK_PORT`).
   - Authorization Header: o mesmo valor de `SEER_WEBHOOK_SECRET`.
   - JSON Payload: deixe o padrão (não precisa customizar).
   - Notification Types: habilite pelo menos "Request Approved" e "Media Available" (e opcionalmente "Request Automatically Approved").
4. Reinicie o `bot` (`docker compose restart bot` ou `bin/bot` local) e teste pelo botão de teste do Seerr ou fazendo um pedido de verdade.

## Comandos

- `$toca <nome ou link>`: toca uma música (aceita nome pra buscar no YouTube, link do YouTube, ou link de faixa/álbum/playlist do Spotify).
- `$toca`: retoma a música pausada ou a próxima da fila.
- `$pausa_pofavo`: pausa a música atual.
- `$para_de_toca`: para de tocar e limpa a fila.
- `$pula`: pula a música atual.
- `$fila`: mostra a fila de músicas.
- `$mistura`: embaralha a fila.
- `$limpa_fila`: limpa a fila sem parar a música atual.
- `$sai_daqui`: o bot sai do canal de voz.
- `$convite`: link de convite do bot.
- `$ajuda`: lista de comandos.

## Contributing

Contributions are welcome! If you have any ideas or improvements, feel free to submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
