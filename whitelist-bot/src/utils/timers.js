// Gestión de temporizadores de borrado automático (aviso previo + borrado)
const config = require('./config');
const store = require('./store');
const { embed } = require('./embeds');

const timers = new Map(); // channelId -> { warn, del }

function clear(channelId) {
  const t = timers.get(channelId);
  if (t) {
    clearTimeout(t.warn);
    clearTimeout(t.del);
    timers.delete(channelId);
  }
}

/** Borra un canal de ticket de forma segura y lo quita del almacén */
async function deleteTicketChannel(client, channelId, reason) {
  clear(channelId);
  store.remove(channelId);
  try {
    const channel = await client.channels.fetch(channelId).catch(() => null);
    if (channel) await channel.delete(reason);
  } catch (err) {
    // 10003 = Unknown Channel (ya borrado). Cualquier otro error se registra.
    if (err.code !== 10003) console.error(`[timers] No se pudo borrar ${channelId}:`, err.message);
  }
}

/** Programa (o reprograma) el aviso y el borrado según ticket.deadline */
function schedule(client, ticket) {
  clear(ticket.channelId);
  if (!ticket.deadline || ticket.completed) return;

  const remaining = ticket.deadline - Date.now();
  if (remaining <= 0) {
    deleteTicketChannel(client, ticket.channelId, 'Plantilla de whitelist no enviada a tiempo');
    return;
  }

  const entry = {};
  const warnMs = config.warningMinutesBefore * 60_000;
  if (warnMs > 0 && !ticket.warned && remaining > warnMs) {
    entry.warn = setTimeout(async () => {
      try {
        const current = store.get(ticket.channelId);
        if (!current || current.completed) return;
        store.set(ticket.channelId, { warned: true });
        const channel = await client.channels.fetch(ticket.channelId).catch(() => null);
        if (!channel) return store.remove(ticket.channelId);
        await channel.send({
          content: `<@${ticket.ownerId}>`,
          embeds: [embed('warning', '⏰ Último aviso',
            `Quedan **${config.warningMinutesBefore} minutos** para enviar la plantilla rellenada. ` +
            'Si no la envías, el ticket se eliminará automáticamente.')],
        });
      } catch (err) {
        console.error('[timers] Error enviando aviso:', err.message);
      }
    }, remaining - warnMs);
  }

  entry.del = setTimeout(() => {
    const current = store.get(ticket.channelId);
    if (!current || current.completed) return;
    deleteTicketChannel(client, ticket.channelId, 'Plantilla de whitelist no enviada a tiempo');
  }, remaining);

  timers.set(ticket.channelId, entry);
}

/** Al arrancar: retoma temporizadores pendientes y limpia tickets de canales inexistentes */
async function restoreAll(client) {
  for (const ticket of store.all()) {
    const channel = await client.channels.fetch(ticket.channelId).catch(() => null);
    if (!channel) {
      store.remove(ticket.channelId);
      continue;
    }
    schedule(client, ticket);
  }
  console.log(`[timers] ${store.all().length} ticket(s) activos restaurados.`);
}

module.exports = { schedule, clear, deleteTicketChannel, restoreAll };
