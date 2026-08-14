# bot-mae

Bot de Discord (Ruby puro, sem Rails) que toca música em canais de voz. Ver README.md para como rodar.

## Estrutura

Todo o código do bot vive em `lib/bot_mae/`. Dois processos: `bin/bot` (conecta no Discord, único lugar que instancia `Discordrb::Commands::CommandBot` — não roda em thread/worker) e `bin/worker` (Sidekiq, processa busca de playlists do Spotify). `RedisCache` (`lib/bot_mae/redis_cache.rb`) substitui o antigo `Rails.cache`.

Busca de vídeo no YouTube usa a **YouTube Data API v3** (`lib/bot_mae/youtube_search_crawler.rb`), não mais scraping via Puppeteer/Chromium (removido — ver histórico do repo se precisar entender o motivo da troca).

## Bloqueio conhecido: DAVE/E2EE no discordrb (IMPORTANTE — trocar depois)

Desde 2026-03-02 o Discord exige o protocolo DAVE (E2EE) em toda chamada de voz não-Stage, inclusive para bots. A gem `discordrb` publicada (3.8.0) **não implementa DAVE** — qualquer tentativa de tocar áudio falha com `VWS error: E2EE/DAVE protocol required`.

Situação upstream:
- Issue: https://github.com/shardlab/discordrb/issues/448
- PR (aberto, não mergeado, desde 2026-05): https://github.com/shardlab/discordrb/pull/453 — adiciona suporte DAVE via bindings FFI para a `libdave` (biblioteca C++ oficial do Discord, https://github.com/discord/libdave).

**Solução aplicada enquanto o PR não é mergeado:**
- `Gemfile` aponta `discordrb` para o commit do PR: `github: 'coderobe/discordrb-dave', ref: 'dce74da589e786552f88886ba77754b9ebc53446'` (SHA fixo, não branch, pra não mudar de baixo sem querer).
- `Dockerfile` compila a `libdave` (tag oficial `v1.1.1/cpp` do repo `discord/libdave`, que já inclui `bindings_capi.cpp` — API em C usada pelos bindings FFI) e sua dependência `mlspp` (commit `1cc50a124a3bc4e143a787ec934280dc70c1034d` do repo `cisco/mlspp`), seguindo as flags de build do Homebrew Formula de referência (`coderobe/homebrew-libdave`):
  - `mlspp`: `cmake -DBUILD_SHARED_LIBS=ON -DTESTING=OFF -DDISABLE_GREASE=ON -DMLS_CXX_NAMESPACE=mlspp`
  - `libdave/cpp`: `cmake -DBUILD_SHARED_LIBS=ON -DTESTING=OFF -DPERSISTENT_KEYS=OFF`
  - Deps via apt: `cmake`, `libssl-dev`, `nlohmann-json3-dev`.
  - Resultado: `libdave.so` instalado em local padrão do linker (`ldconfig` roda depois do install).

**Bug adicional encontrado e corrigido via monkeypatch** (`lib/bot_mae/patches/discordrb_dave_transition_fix.rb`, carregado por `lib/bot_mae/bot.rb`): quando o bot é o primeiro a entrar no canal de voz (cria o grupo MLS do zero), o Discord manda `DAVE_MLS_ANNOUNCE_COMMIT_TRANSITION` direto, sem `DAVE_PREPARE_TRANSITION` antes. `VoiceWS#process_dave_commit` do PR não passa `activate_pending_session: true` pro `track_pending_transition` nesse caso (diferente do `process_dave_welcome`, que passa), então a transição nunca executa e a conexão de voz fica muda pra sempre até o Discord fechar com código 4014. O patch corrige só essa chamada. Remover junto com a troca pro gem oficial quando o PR for mergeado (ou reportar o bug no PR).

**Status confirmado (2026-08-11):** handshake DAVE completo (key package, MLS proposals, commit/welcome, transição) e conexão de voz criptografada funcionam de ponta a ponta contra o Discord real, de forma repetível. O bloqueio de voz está resolvido.

**Quando trocar/revisitar:**
- Se o PR #453 for mergeado e uma nova versão do gem `discordrb` for publicada no RubyGems, trocar o `Gemfile` de volta pra gem normal (`gem 'discordrb'`, sem `github:`/`branch:`) e remover a etapa de build da `libdave`/`mlspp` do Dockerfile.
- Se o fork `coderobe/discordrb-dave` for atualizado/rebaseado, vale checar se os commits/tags de `mlspp`/`libdave` usados aqui ainda são os recomendados.
- Se esse workaround não funcionar de forma estável em produção, considerar como alternativa usar um canal de voz do tipo **Stage** (não fica claro se está isento da exigência de DAVE) ou aguardar o merge oficial.

## Bug corrigido: recursão infinita em `recursive_queue_play`

`Helpers#recursive_queue_play` (`lib/bot_mae/helpers.rb`) era auto-recursivo sem nenhum `sleep`. Quando a reprodução falhava sem remover a música da fila (ex: `yt-dlp`/`ffmpeg` falhando antes do `.play()` terminar, ou `isplaying?` ficando "travado" em `true` por um estado de voz anterior), cada chamada recursiva repetia exatamente o mesmo estado — recursão infinita até `SystemStackError: stack level too deep` (~8700 frames), travando a thread do comando (bot fica mudo, sem responder nada). Convertido pra um `loop` explícito com `sleep 0.5` de guarda; funcionalmente equivalente (o `.play()` do discordrb bloqueia até a música acabar, então o loop normal não gira rápido).

## Bug corrigido: `$toca` durante playback cria loop de reprodução duplicado

`bot.command(:toca)` (`lib/bot_mae/mae_music.rb`) chama `helper.recursive_queue_play` toda vez que a fila fica não-vazia, sem checar se já existe um loop rodando pra aquele canal. Como o discordrb roda cada comando numa `Thread.new` própria, dar `$toca <B>` enquanto `<A>` ainda tocava criava um **segundo** `recursive_queue_play` concorrente pro mesmo canal. Esse segundo loop via `isplaying?` como `false` na janela síncrona entre `VoiceWS#stop_playing` (usado por `$pula`) setar `@playing = false` e o `play()` bloqueante do loop original de fato retornar (só aí que ele roda `shift_queue`) — e nessa janela tocava `user_queue[0]` de novo, ou seja, a música que devia ter sido pulada. Resultado observado: `$pula` "pulava" mas voltava a tocar a mesma música, e um `$pula` seguinte via a fila já encolhida pelo loop original e concluía (errado) que não tinha mais nada pra tocar.

Corrigido com lock em memória por canal (`"#{server_id}_#{voice_channel_id}"`) em `Helpers.claim_playback_channel`/`release_playback_channel` (`lib/bot_mae/helpers.rb`), reivindicado no início de `recursive_queue_play` e liberado num `ensure`. Só funciona porque `bin/bot` é processo único (não roda em worker/thread externa — ver seção "Estrutura"); se isso mudar, esse lock em memória para de bastar e precisa virar lock distribuído (Redis `SETNX`/similar).

## Notificações do Seerr (pedido aprovado / disponível) via DM

`lib/bot_mae/seer_webhook_server.rb` (`DiscordBot::SeerWebhookServer`) roda um `WEBrick::HTTPServer` numa thread própria, subida por `DiscordBot::Bot#initialize` (`lib/bot_mae/bot.rb`) — só se `SEER_WEBHOOK_SECRET` estiver setado, seguindo o mesmo padrão de "feature opcional via env var" do `YTDLP_COOKIES_FILE`. Roda dentro do processo `bin/bot` (não do `bin/worker`/Sidekiq) porque só esse processo tem a instância do `Discordrb::Commands::CommandBot` — mandar DM (`bot.user(id).pm`) exige essa instância; não dá pra bridgear isso via Sidekiq/Redis sem reinventar a roda.

Duas descobertas que moldaram esse design (confirmadas lendo doc + código-fonte do Seerr, `seerr-team/seerr`, em 2026-08-13):
- O agente nativo **"Discord"** do Seerr (Settings → Notifications → Discord) nunca manda DM — só posta num canal compartilhado via webhook, usando o Discord ID cadastrado por cada usuário só pra gerar uma `@menção` dentro dessa mensagem de canal (`server/lib/notifications/agents/discord.ts`). Por isso essa feature existe: o Seerr sozinho não resolve "avisar só a pessoa que pediu, em privado".
- O agente genérico **"Webhook"** do Seerr (diferente do "Discord") já manda, no payload JSON **padrão** (sem customizar nada), o campo `request.requestedBy_settings_discordIds` — a mesma lista de Discord IDs que o usuário cadastrou na tela acima. Por causa disso, `SeerWebhookServer` **não precisa de nenhum mapeamento próprio nem de chamar a API do Seerr**: o(s) Discord ID(s) de quem deve receber a DM já vêm prontos no payload. Se vier vazio (usuário não cadastrou o Discord ID no Seerr), só loga e ignora.

Tipos de notificação tratados: `MEDIA_APPROVED`/`MEDIA_AUTO_APPROVED` (aprovado) e `MEDIA_AVAILABLE` (disponível); qualquer outro tipo é ignorado com 200 (evita retry do Seerr). Configuração de ponta a ponta documentada no README.

**Bug corrigido: DMs de "aprovado" e "disponível" chegavam com conteúdo idêntico.** `SeerWebhookServer#build_embed` (`lib/bot_mae/seer_webhook_server.rb`) só usava `payload['subject']` (título) e `payload['message']` (sinopse do TMDB) — campos que não mudam entre os tipos de notificação pro mesmo título. O `notification_type` já era lido e validado em `process_notification`, mas nunca aparecia na mensagem, então as duas DMs pareciam a mesma notificação repetida. Corrigido mapeando `notification_type` pra um rótulo em `NOTIFICATION_LABELS` (pt-BR, ex. "Pedido aprovado" / "Já disponível") setado em `embed.author`. Não usa o campo `event` que o Seerr manda no payload (também distingue os tipos) porque esse vem em inglês, sem tradução — inconsistente com o resto das mensagens do bot.

## Bloqueio observado: YouTube anti-bot (429 / "Sign in to confirm you're not a bot")

O `yt-dlp` é bloqueado pelo YouTube por **IP**, não por vídeo específico: `HTTP Error 429: Too Many Requests` + `Sign in to confirm you're not a bot`. Aconteceu tanto no sandbox de desenvolvimento quanto depois em produção (máquina do usuário), então não é só bloqueio do ambiente de teste — instalar `deno` (feito, resolve o aviso de "no JS runtime") não resolve isso.

**Solução aplicada:** suporte a cookies no `yt-dlp` via env var `YTDLP_COOKIES_FILE` (lida em `Helpers#ytdlp_cookies_option`, `lib/bot_mae/helpers.rb`), que adiciona `--cookies <arquivo>` no comando quando o arquivo existe. Com Docker, o `docker-compose.yml` sempre monta `./cookies.txt` (repo root, gitignored) em `/app/cookies.txt` nos serviços `bot` e `worker` — por isso o arquivo precisa existir (mesmo vazio, `touch cookies.txt`) pra `docker compose up` funcionar, ver README. O conteúdo é um arquivo de cookies formato Netscape exportado de uma conta Google logada (extensão tipo "Get cookies.txt LOCALLY"); sem esse arquivo (vazio), o `yt-dlp` roda sem `--cookies`, igual antes.

**Bug adicional: mount do cookies.txt precisa ser read-write E o arquivo precisa ser gravável pelo uid do container.** Com `--cookies <arquivo>`, o `yt-dlp` sempre tenta regravar o cookie jar nesse mesmo arquivo ao final de cada download (via `YoutubeDL#close` → `save_cookies`), não só na primeira leitura — é assim que ele persiste cookies de sessão renovados pelo YouTube. Duas causas possíveis de falha nessa gravação, ambas derrubam o pipe `yt-dlp | ffmpeg` (aparece como `ERROR: Unable to download video: [Errno 32] Broken pipe`) e a música não toca:
- Mount `:ro` no `docker-compose.yml` → `OSError: Read-only file system`. Precisa ser `./cookies.txt:/app/cookies.txt` (sem `:ro`).
- Mesmo com mount read-write, o container roda como usuário `bot` (uid **1000**, ver `Dockerfile`). Bind mount preserva o uid/dono do arquivo no host; se o `cookies.txt` no host pertencer a um uid diferente de 1000 (comum — o uid do usuário do host raramente é 1000) com permissão `644`, o container cai em "outros" e só tem leitura → `PermissionError: [Errno 13] Permission denied`. Precisa `chmod 666 cookies.txt` (ou `chown` pro uid 1000) no host.
