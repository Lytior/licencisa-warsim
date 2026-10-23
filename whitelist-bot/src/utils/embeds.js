// Constructores de embeds y componentes reutilizables
const {
  EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle, StringSelectMenuBuilder,
} = require('discord.js');
const config = require('./config');
const { slugify } = require('./text');

const IDS = {
  OPEN: 'ticket_open',
  CLOSE: 'ticket_close',
  COUNTRY: 'ticket_country',
};

const embed = (color, title, description) =>
  new EmbedBuilder().setColor(config.colors[color]).setTitle(title).setDescription(description).setTimestamp();

function panelMessage() {
  return {
    embeds: [embed('primary', '📋 Whitelist',
      'Pulsa el botón de abajo para abrir un ticket de whitelist.\n' +
      'Se creará un canal privado donde podrás elegir tu país y enviar tu solicitud.')],
    components: [new ActionRowBuilder().addComponents(
      new ButtonBuilder().setCustomId(IDS.OPEN).setLabel('Abrir ticket').setEmoji('🎫').setStyle(ButtonStyle.Primary),
    )],
  };
}

function closeRow() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId(IDS.CLOSE).setLabel('Cerrar ticket').setEmoji('🔒').setStyle(ButtonStyle.Danger),
  );
}

function countryRow(disabled = false, selected = null) {
  const menu = new StringSelectMenuBuilder()
    .setCustomId(IDS.COUNTRY)
    .setPlaceholder(selected ? `Seleccionado: ${selected}` : 'Selecciona tu país')
    .setDisabled(disabled)
    .addOptions(config.countries.slice(0, 25).map((c) => ({
      label: c.name,
      value: slugify(c.name),
      emoji: c.emoji,
      default: selected === c.name,
    })));
  return new ActionRowBuilder().addComponents(menu);
}

function welcomeMessage(userId) {
  return {
    content: `<@${userId}>`,
    embeds: [embed('primary', '👋 ¡Bienvenido/a a tu ticket de whitelist!',
      'Selecciona en el menú de abajo el **país** para el que solicitas la whitelist.\n' +
      'Una vez elegido no se podrá cambiar.')],
    components: [countryRow(), closeRow()],
  };
}

module.exports = { IDS, embed, panelMessage, closeRow, countryRow, welcomeMessage };
