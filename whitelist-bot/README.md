# Bot de tickets de whitelist (discord.js v14)

## Estructura
```
whitelist-bot/
├── config.json            # Canal, categoría, rol staff, países, plantilla, tiempos
├── .env.example           # Token, Client ID y Guild ID
├── package.json
├── data/tickets.json      # (se crea solo) persistencia de tickets activos
└── src/
    ├── index.js           # Arranque, carga de comandos y eventos
    ├── deploy-commands.js # Registra /panel en el servidor
    ├── commands/panel.js
    ├── events/            # ready, interactionCreate, messageCreate, channelDelete
    └── utils/             # config, store, timers, tickets, embeds, text
```

## Instalación
1. Node.js 18 o superior.
2. `npm install`
3. Copia `.env.example` a `.env` y rellena `DISCORD_TOKEN`, `CLIENT_ID` y `GUILD_ID`.
4. Edita `config.json`: `ticketChannelId`, `categoryId`, `staffRoleId`, países, plantilla y `timeLimitMinutes` (por defecto 120).
   (Activa el *Modo desarrollador* en Discord → clic derecho → *Copiar ID*.)
5. `npm run deploy` (registra `/panel`; solo hace falta repetirlo si cambias comandos).
6. `npm start`
7. En el canal de tickets, un administrador ejecuta `/panel`.

## Developer Portal
**Bot → Privileged Gateway Intents:** activa **Message Content Intent**.
Intents usados en código: `Guilds`, `GuildMessages`, `MessageContent`.

**Invitación (OAuth2 → URL Generator):** scopes `bot` y `applications.commands`, con los permisos:
Gestionar canales, Ver canales, Enviar mensajes, Gestionar mensajes, Insertar enlaces, Leer historial de mensajes.

> El rol del bot debe tener esos permisos también en la categoría de tickets.

## Notas
- La plantilla se detecta cuando un mensaje del dueño contiene todos los `template.requiredFields` (sin distinguir mayúsculas ni tildes).
- `warningMinutesBefore` (15) envía un aviso antes del borrado; pon `0` para desactivarlo.
- Al reiniciar, los temporizadores pendientes se retoman y los vencidos se borran al momento.
- Discord limita el renombrado de un canal a 2 veces cada 10 minutos.
