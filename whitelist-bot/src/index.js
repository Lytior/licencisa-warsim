// Punto de entrada del bot
const fs = require('node:fs');
const path = require('node:path');
const { Client, Collection, GatewayIntentBits } = require('discord.js');
const config = require('./utils/config');

if (!config.token) {
  console.error('❌ Falta DISCORD_TOKEN en el archivo .env');
  process.exit(1);
}

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

// Cargar comandos
client.commands = new Collection();
for (const file of fs.readdirSync(path.join(__dirname, 'commands')).filter((f) => f.endsWith('.js'))) {
  const command = require(path.join(__dirname, 'commands', file));
  client.commands.set(command.data.name, command);
}

// Cargar eventos
for (const file of fs.readdirSync(path.join(__dirname, 'events')).filter((f) => f.endsWith('.js'))) {
  const event = require(path.join(__dirname, 'events', file));
  const handler = (...args) => Promise.resolve(event.execute(...args)).catch((err) =>
    console.error(`[evento ${event.name}] Error:`, err));
  if (event.once) client.once(event.name, handler);
  else client.on(event.name, handler);
}

// Que ningún error no capturado tumbe el bot
client.on('error', (err) => console.error('[client] Error:', err));
process.on('unhandledRejection', (err) => console.error('[unhandledRejection]', err));
process.on('uncaughtException', (err) => console.error('[uncaughtException]', err));

client.login(config.token);
