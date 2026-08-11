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

## Bloqueio observado: YouTube anti-bot no ambiente de teste

Durante os testes (sandbox de desenvolvimento), o `yt-dlp` foi bloqueado pelo YouTube mesmo para vídeos nunca tentados antes: `HTTP Error 429: Too Many Requests` + `Sign in to confirm you're not a bot`. Como aconteceu com IDs de vídeo diferentes, é bloqueio por **IP** (do ambiente sandbox), não algo específico do vídeo ou do nosso código — instalar `deno` (feito, resolve o aviso de "no JS runtime") não resolveu isso. Testar de novo rodando o `docker compose up` numa máquina/rede diferente (a do usuário, fora do sandbox) antes de investigar mais a fundo (cookies via `--cookies-from-browser`/`--cookies`, ver https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp).
