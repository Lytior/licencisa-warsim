// Evento channelDelete: si alguien borra un ticket a mano, se limpia el almacén
const { Events } = require('discord.js');
const store = require('../utils/store');
const timers = require('../utils/timers');

module.exports = {
  name: Events.ChannelDelete,
  execute(channel) {
    if (store.get(channel.id)) {
      timers.clear(channel.id);
      store.remove(channel.id);
    }
  },
};
