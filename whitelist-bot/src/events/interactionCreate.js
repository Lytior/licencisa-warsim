// Evento interactionCreate: comandos slash, botones y menús
const { Events, MessageFlags } = require('discord.js');
const tickets = require('../utils/tickets');
const { IDS, embed } = require('../utils/embeds');

module.exports = {
  name: Events.InteractionCreate,
  async execute(interaction) {
    try {
      if (interaction.isChatInputCommand()) {
        const command = interaction.client.commands.get(interaction.commandName);
        if (command) await command.execute(interaction);
      } else if (interaction.isButton()) {
        if (interaction.customId === IDS.OPEN) await tickets.createTicket(interaction);
        else if (interaction.customId === IDS.CLOSE) await tickets.closeTicket(interaction);
      } else if (interaction.isStringSelectMenu() && interaction.customId === IDS.COUNTRY) {
        await tickets.selectCountry(interaction);
      }
    } catch (err) {
      console.error('[interaction] Error:', err);
      const payload = { embeds: [embed('danger', '❌ Error', 'Ha ocurrido un error inesperado.')], flags: MessageFlags.Ephemeral };
      if (interaction.deferred || interaction.replied) await interaction.followUp(payload).catch(() => {});
      else await interaction.reply(payload).catch(() => {});
    }
  },
};
