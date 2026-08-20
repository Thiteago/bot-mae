# Discord Bot Mãe

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Description

Bot de Discord (Ruby puro, sem framework web) que manda DM avisando quando um pedido de mídia no [Seerr](https://github.com/seerr-team/seerr) é aprovado ou fica disponível.

## Rodando com Docker (recomendado)

1. Copie `.env.example` para `.env` e preencha `DISCORD_BOT_TOKEN` / `DISCORD_BOT_CLIENT_ID`, criados em https://discord.com/developers/applications.
2. Suba tudo:

   ```bash
   docker compose up --build
   ```

3. Convide o bot pro seu servidor usando o comando `$convite` (ou monte o link manualmente com o `DISCORD_BOT_CLIENT_ID`).

## Rodando sem Docker

Requer Ruby 3.4.1 (ver `.ruby-version`).

```bash
bundle install
bin/bot
```

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

- `$convite`: link de convite do bot.
- `$ajuda`: lista de comandos.

## Contributing

Contributions are welcome! If you have any ideas or improvements, feel free to submit a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
