// Carga y valida la configuración (config.json + .env)
require('dotenv').config();
const path = require('node:path');
const config = require(path.join(__dirname, '..', '..', 'config.json'));

config.token = process.env.DISCORD_TOKEN;
config.clientId = process.env.CLIENT_ID;
config.guildId = process.env.GUILD_ID;
config.timeLimitMinutes = Number(config.timeLimitMinutes) || 120;
config.warningMinutesBefore = Number(config.warningMinutesBefore) || 0;
config.closeDelaySeconds = Number(config.closeDelaySeconds) || 5;

// Convierte "#RRGGBB" a número para los embeds
for (const [k, v] of Object.entries(config.colors)) {
  config.colors[k] = typeof v === 'string' ? parseInt(v.replace('#', ''), 16) : v;
}

module.exports = config;
