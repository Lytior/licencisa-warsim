// Lógica principal de los tickets: crear, elegir país, cerrar
const { ChannelType, PermissionFlagsBits, MessageFlags } = require('discord.js');
const config = require('./config');
const store = require('./store');
const timers = require('./timers');
const { IDS, embed, closeRow } = require('./embeds');
const { slugify } = require('./text');

const creating = new Set(); // evita doble clic creando dos tickets a la vez
const ephemeral = (e) => ({ embeds: [e], flags: MessageFlags.Ephemeral });

async function createTicket(interaction) {
  const { guild, user } = interaction;
  const country = config.countries.find((c) => IDS.OPEN + slugify(c.name) === interaction.customId);
  if (!country) {
    return interaction.reply(ephemeral(embed('danger', '❌ Error', 'Ese país ya no está disponible.')));
  }

  if (interaction.channelId !== config.ticketChannelId) {
    return interaction.reply(ephemeral(embed('danger', '❌ Canal incorrecto', 'Este botón solo funciona en el canal de tickets.')));
  }

  // ¿Ya tiene un ticket abierto? Se comprueba también que el canal siga existiendo.
  const existing = store.findByOwner(guild.id, user.id);
  if (existing) {
    const ch = await guild.channels.fetch(existing.channelId).catch(() => null);
    if (ch) {
      return interaction.reply(ephemeral(embed('warning', '⚠️ Ya tienes un ticket abierto', `Tu ticket: ${ch}`)));
    }
    timers.clear(existing.channelId);
    store.remove(existing.channelId);
  }
  if (creating.has(user.id)) {
    return interaction.reply(ephemeral(embed('warning', '⏳ Espera', 'Tu ticket se está creando...')));
  }

  creating.add(user.id);
  await interaction.deferReply({ flags: MessageFlags.Ephemeral });
  try {
    const channel = await guild.channels.create({
      name: `wl-${slugify(country.name)}`,
      type: ChannelType.GuildText,
      parent: config.categoryId,
      topic: `Ticket de whitelist de ${user.tag} (${user.id})`,
      permissionOverwrites: [
        { id: guild.roles.everyone.id, deny: [PermissionFlagsBits.ViewChannel] },
        {
          id: user.id,
          allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages,
            PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.AttachFiles],
        },
        {
          id: config.staffRoleId,
          allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages,
            PermissionFlagsBits.ReadMessageHistory, PermissionFlagsBits.ManageMessages],
        },
        {
          id: interaction.client.user.id,
          allow: [PermissionFlagsBits.ViewChannel, PermissionFlagsBits.SendMessages,
            PermissionFlagsBits.ManageChannels, PermissionFlagsBits.ManageMessages,
            PermissionFlagsBits.EmbedLinks, PermissionFlagsBits.ReadMessageHistory],
        },
      ],
    });

    const deadline = Date.now() + config.timeLimitMinutes * 60_000;
    const ticket = store.set(channel.id, {
      guildId: guild.id, ownerId: user.id, createdAt: Date.now(),
      country: country.name, deadline, warned: false, completed: false,
    });

    await sendTemplate(channel, ticket, country);
    timers.schedule(interaction.client, ticket);
    await interaction.editReply({ embeds: [embed('success', '✅ Ticket creado', `Tu ticket: ${channel}`)] });
  } catch (err) {
    console.error('[tickets] Error creando ticket:', err);
    const msg = err.code === 50013
      ? 'El bot no tiene permisos suficientes (Gestionar canales / Ver canales).'
      : 'No se pudo crear el ticket. Revisa la configuración (categoría, rol de staff).';
    await interaction.editReply({ embeds: [embed('danger', '❌ Error', msg)] }).catch(() => {});
  } finally {
    creating.delete(user.id);
  }
}

/** Envía la plantilla, el aviso de tiempo y el botón de cerrar */
async function sendTemplate(channel, ticket, country) {
  const horas = config.timeLimitMinutes / 60;
  const tiempo = Number.isInteger(horas) ? `${horas} hora${horas === 1 ? '' : 's'}` : `${config.timeLimitMinutes} minutos`;
  const ts = Math.floor(ticket.deadline / 1000);

  await channel.send({
    content: `<@${ticket.ownerId}>`,
    embeds: [
      embed('primary', `${country.emoji} Ficha de personaje — ${country.label || country.name}`, config.template.text),
      embed('warning', '⏳ Tiempo límite',
        `**Tienes ${tiempo} para enviar la plantilla rellenada. ` +
        'Si no la envías, el ticket se eliminará automáticamente.**\n' +
        `Fecha límite: <t:${ts}:F> (<t:${ts}:R>)`),
    ],
    components: [closeRow()],
  });
}

async function closeTicket(interaction) {
  const ticket = store.get(interaction.channelId);
  const isStaff = interaction.member?.roles?.cache?.has(config.staffRoleId);
  const isOwner = ticket && ticket.ownerId === interaction.user.id;

  if (!isStaff && !isOwner) {
    return interaction.reply(ephemeral(embed('danger', '⛔ No permitido', 'Solo el staff o el dueño del ticket pueden cerrarlo.')));
  }

  timers.clear(interaction.channelId);
  if (ticket) store.set(interaction.channelId, { completed: true }); // evita borrados duplicados
  await interaction.reply({
    embeds: [embed('danger', '🔒 Cerrando ticket', `Cerrado por ${interaction.user}. El canal se eliminará en ${config.closeDelaySeconds} segundos.`)],
  }).catch(() => {});

  setTimeout(() => {
    timers.deleteTicketChannel(interaction.client, interaction.channelId, `Ticket cerrado por ${interaction.user.tag}`);
  }, config.closeDelaySeconds * 1000);
}

module.exports = { createTicket, closeTicket };
