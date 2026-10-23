// Registra los comandos slash en el servidor (ejecutar con: npm run deploy)
const fs = require('node:fs');
const path = require('node:path');
const { REST, Routes } = require('discord.js');
const config = require('./utils/config');

if (!config.token || !config.clientId || !config.guildId) {
  console.error('❌ Faltan DISCORD_TOKEN, CLIENT_ID o GUILD_ID en el .env');
  process.exit(1);
}

const commands = fs.readdirSync(path.join(__dirname, 'commands'))
  .filter((f) => f.endsWith('.js'))
  .map((f) => require(path.join(__dirname, 'commands', f)).data.toJSON());

(async () => {
  try {
    const rest = new REST().setToken(config.token);
    await rest.put(Routes.applicationGuildCommands(config.clientId, config.guildId), { body: commands });
    console.log(`✅ ${commands.length} comando(s) registrados en el servidor.`);
  } catch (err) {
    console.error('❌ Error registrando comandos:', err);
  }
})();
