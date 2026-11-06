-- Item consumible para ESX (tabla `items` de es_extended)
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`)
VALUES ('cuerda_arnes', 'Cuerda con arnés', 2, 0, 1)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);

-- Tienda: añadir 'cuerda_arnes' en el sistema de tienda existente del servidor
-- con el precio que decidais (no se incluye logica de precio aqui).
