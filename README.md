# Discord Bot Mãe

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Description

Bot de Discord (Ruby puro, sem framework web) que toca música em canais de voz: busca no YouTube, playlists/álbuns/faixas do Spotify, fila por canal de voz, pular/pausar/embaralhar.

## Rodando com Docker (recomendado)

1. Copie `.env.example` para `.env` e preencha:
   - `DISCORD_BOT_TOKEN` / `DISCORD_BOT_CLIENT_ID`: criados em https://discord.com/developers/applications
   - `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET`: criados em https://developer.spotify.com/dashboard
   - `YOUTUBE_API_KEY`: crie um projeto em https://console.cloud.google.com, ative a "YouTube Data API v3" e gere uma API key. A cota gratuita padrão é 10.000 unidades/dia (cada busca custa 100, ~100 buscas/dia de graça — suficiente pra uso pessoal).
2. Suba tudo:

   ```bash
   docker compose up --build
   ```

   Isso inicia três serviços: `redis` (fila/estado), `bot` (conexão com o Discord) e `worker` (Sidekiq, processa playlists do Spotify em background).

3. Convide o bot pro seu servidor usando o comando `$convite` (ou monte o link manualmente com o `DISCORD_BOT_CLIENT_ID`).

## Rodando sem Docker

Requer Ruby 3.4.1 (ver `.ruby-version`), Redis rodando localmente, e os binários `ffmpeg` e `yt-dlp` no PATH.

```bash
bundle install
bin/bot      # processo do bot (conecta no Discord)
bin/worker   # processo do Sidekiq, em outro terminal
```

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
