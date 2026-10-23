// Comando /panel: envía el panel de tickets (solo administradores)
const { SlashCommandBuilder, PermissionFlagsBits, MessageFlags } = require('discord.js');
const config = require('../utils/config');
const { embed, panelMessage } = require('../utils/embeds');

module.exports = {
  data: new SlashCommandBuilder()
    .setName('panel')
    .setDescription('Envía el panel para abrir tickets de whitelist')
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .setDMPermission(false),

  async execute(interaction) {
    if (!interaction.memberPermissions?.has(PermissionFlagsBits.Administrator)) {
      return interaction.reply({ embeds: [embed('danger', '⛔ No permitido', 'Solo los administradores pueden usar este comando.')], flags: MessageFlags.Ephemeral });
    }
    if (interaction.channelId !== config.ticketChannelId) {
      return interaction.reply({ embeds: [embed('danger', '❌ Canal incorrecto', `Este comando solo funciona en <#${config.ticketChannelId}>.`)], flags: MessageFlags.Ephemeral });
    }
    await interaction.channel.send(panelMessage());
    await interaction.reply({ embeds: [embed('success', '✅ Panel enviado', 'El panel de tickets se ha publicado.')], flags: MessageFlags.Ephemeral });
  },
};
