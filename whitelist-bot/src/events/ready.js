// Evento ready: el bot está conectado; se restauran los temporizadores
const { Events } = require('discord.js');
const timers = require('../utils/timers');

module.exports = {
  name: Events.ClientReady,
  once: true,
  async execute(client) {
    console.log(`✅ Conectado como ${client.user.tag}`);
    await timers.restoreAll(client).catch((err) => console.error('[ready] Error restaurando tickets:', err));
  },
};
