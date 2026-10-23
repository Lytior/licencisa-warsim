// Evento messageCreate: detecta cuando el usuario envía la plantilla rellenada
const { Events } = require('discord.js');
const config = require('../utils/config');
const store = require('../utils/store');
const timers = require('../utils/timers');
const { embed } = require('../utils/embeds');
const { normalize } = require('../utils/text');

module.exports = {
  name: Events.MessageCreate,
  async execute(message) {
    if (message.author.bot || !message.guild) return;

    const ticket = store.get(message.channelId);
    // Solo nos interesan tickets con país elegido, pendientes y mensajes del dueño
    if (!ticket || !ticket.deadline || ticket.completed || message.author.id !== ticket.ownerId) return;

    const content = normalize(message.content);
    const ok = config.template.requiredFields.every((field) => content.includes(normalize(field)));
    if (!ok) return;

    try {
      timers.clear(ticket.channelId);
      store.set(ticket.channelId, { completed: true, submittedAt: Date.now() });
      await message.reply({
        content: `<@&${config.staffRoleId}>`,
        allowedMentions: { roles: [config.staffRoleId], users: [ticket.ownerId] },
        embeds: [embed('success', '✅ Plantilla recibida',
          `Gracias ${message.author}, tu solicitud ha sido recibida y el borrado automático se ha cancelado.\n` +
          'El staff revisará tu whitelist lo antes posible.')],
      });
    } catch (err) {
      console.error('[messageCreate] Error confirmando plantilla:', err.message);
    }
  },
};
