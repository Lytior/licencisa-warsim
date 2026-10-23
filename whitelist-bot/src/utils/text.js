// Utilidades de texto

/** Quita tildes, pasa a minúsculas y deja solo [a-z0-9-] (ej. "España" -> "espana") */
function slugify(str) {
  return String(str)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 90) || 'usuario';
}

/** Normaliza para comparar sin tildes ni mayúsculas */
function normalize(str) {
  return String(str).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

module.exports = { slugify, normalize };
