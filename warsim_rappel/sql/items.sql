-- Objeto "cuerda con arnés" para el inventario por defecto de ESX (tabla `items`).
-- Solo define el ítem: el precio y la compra los gestiona la tienda de objetos existente.
INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`)
VALUES ('cuerda_arnes', 'Cuerda con arnés', 2, 0, 1)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`);
