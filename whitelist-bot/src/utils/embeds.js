// Constructores de embeds y componentes reutilizables
const {
  EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle,
} = require('discord.js');
const config = require('./config');
const { slugify } = require('./text');

const IDS = {
  OPEN: 'ticket_open:', // + slug del país (ej. ticket_open:espana)
  CLOSE: 'ticket_close',
};

const embed = (color, title, description) =>
  new EmbedBuilder().setColor(config.colors[color]).setTitle(title).setDescription(description).setTimestamp();

/** Panel estilo "Ticket Tool": embed con barra de color y un botón gris por país */
function panelMessage() {
  const { panel } = config;
  const panelEmbed = new EmbedBuilder()
    .setColor(config.colors.panel)
    .setTitle(panel.title)
    .setDescription(panel.description);
  if (panel.footer) panelEmbed.setFooter({ text: panel.footer, iconURL: panel.footerIcon || undefined });

  // Discord permite 5 botones por fila y 5 filas (máx. 25 países)
  const buttons = config.countries.slice(0, 25).map((c) =>
    new ButtonBuilder()
      .setCustomId(IDS.OPEN + slugify(c.name))
      .setLabel(c.label || c.name)
      .setEmoji(c.emoji)
      .setStyle(ButtonStyle.Secondary));
  const components = [];
  for (let i = 0; i < buttons.length; i += 5) {
    components.push(new ActionRowBuilder().addComponents(buttons.slice(i, i + 5)));
  }
  return { embeds: [panelEmbed], components };
}

function closeRow() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId(IDS.CLOSE).setLabel('Cerrar ticket').setEmoji('🔒').setStyle(ButtonStyle.Danger),
  );
}

module.exports = { IDS, embed, panelMessage, closeRow };
