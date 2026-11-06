# warsim_rappel

Sistema de rappel para Operation Warsim (ESX).

## Instalación
1. Copiar `warsim_rappel` a `resources/` y añadir `ensure warsim_rappel` después de `es_extended`.
2. Ejecutar `sql/items.sql`.
3. Añadir `cuerda_arnes` a la tienda existente (precio a elegir).

## Controles
W sube · S baja · Espacio (mantener) impulsos al bajar · E soltarse abajo / trepar arriba.

## Cliente / servidor
- **Servidor** (`server/`): ítem usable, retirada del ítem, registro de quién rapelea, reenvío a jugadores cercanos, limpieza al desconectar.
- **Cliente local** (`client/main.lua`, `movement.lua`, `surface.lua`, `detect.lua`, `exit.lua`, `restrictions.lua`): toda la lógica y física.
- **Clientes remotos** (`client/remote.lua`): reconstruyen la posición a partir de la altura z (interpolada) con un clon local; la cuerda se crea en cada cliente.
- **Animaciones**: solo en `shared/animations.lua`.

## Ajustes probables tras la primera prueba
- `Config.Pose.SlopePitchSign`: si en laderas el personaje se inclina al revés.
- `Config.Pose.BodyOffset`: si los pies no tocan la pared o la atraviesan.
- `Config.IK.LeftArm/RightArm`: índices IK (3/4) si las manos van al revés.
- `Animations.Clips.climb`: clip prototipo, verificar con un visor de anims (si no existe, se omite).
- `Config.Rope.UseNatives = false` para forzar el fallback de prop (`Config.Rope.PropModel`).
