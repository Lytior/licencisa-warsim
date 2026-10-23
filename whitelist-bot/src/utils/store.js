// Persistencia de tickets en un archivo JSON (data/tickets.json)
// Estructura: { [channelId]: { channelId, guildId, ownerId, createdAt, country, deadline, warned, completed } }
const fs = require('node:fs');
const path = require('node:path');

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const FILE = path.join(DATA_DIR, 'tickets.json');

let tickets = {};

function load() {
  try {
    if (fs.existsSync(FILE)) tickets = JSON.parse(fs.readFileSync(FILE, 'utf8')) || {};
  } catch (err) {
    console.error('[store] No se pudo leer tickets.json, se empieza vacío:', err.message);
    tickets = {};
  }
}

function save() {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    // Escritura atómica: primero a un temporal y luego se renombra
    const tmp = `${FILE}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(tickets, null, 2));
    fs.renameSync(tmp, FILE);
  } catch (err) {
    console.error('[store] Error guardando tickets.json:', err.message);
  }
}

const get = (channelId) => tickets[channelId] || null;
const all = () => Object.values(tickets);
const findByOwner = (guildId, ownerId) =>
  all().find((t) => t.guildId === guildId && t.ownerId === ownerId) || null;

function set(channelId, data) {
  tickets[channelId] = { ...(tickets[channelId] || {}), ...data, channelId };
  save();
  return tickets[channelId];
}

function remove(channelId) {
  if (tickets[channelId]) {
    delete tickets[channelId];
    save();
  }
}

load();
module.exports = { get, set, remove, all, findByOwner };
