# warsim_rappel — Sistema de rappel (cuerda con arnés)

Recurso de ESX para **Operation Warsim**. Permite subir y bajar con cuerda por cualquier pared vertical apta del mapa. Se activa con el objeto consumible **"cuerda con arnés"**. No usa puntos de anclaje colocados a mano: el anclaje se calcula con raycast al usar el objeto.

## Instalación

1. Copia la carpeta `warsim_rappel` en `resources/` y añade `ensure warsim_rappel` al `server.cfg` (después de `es_extended`).
2. Define el objeto en el inventario (solo el ítem; la compra y el reparto los hace la tienda de objetos que ya existe):
   - **Inventario por defecto de ESX:** ejecuta `sql/items.sql`.
   - **ox_inventory:** añade esto a `ox_inventory/data/items.lua`:
     ```lua
     ['cuerda_arnes'] = {
         label = 'Cuerda con arnés',
         weight = 2000,
         stack = true,
         close = true,
         consume = 0,
         server = { export = 'warsim_rappel.cuerda_arnes' },
         client = { image = 'nui://warsim_rappel/img/cuerda_arnes.png' },
     },
     ```
     La línea `client = { image = ... }` pone el icono del objeto, que va incluido en este recurso (`img/cuerda_arnes.png`); no hace falta copiarlo a `ox_inventory/web/images`.
     `consume = 0` evita que ox gaste la cuerda al usarla: la gasta el script solo si la superficie es válida. La línea `server = { export = ... }` es la que hace que ox avise al script al usar el objeto.
3. Añade `cuerda_arnes` al catálogo de la tienda de objetos existente con el precio que corresponda.

No hay restricción de rango: cualquier jugador que tenga el objeto puede usarlo.

## Funcionamiento

| Paso | Qué ocurre |
|---|---|
| Usar el objeto | El servidor pide al cliente que busque una superficie válida. |
| Superficie no válida | Se avisa al jugador y el objeto **no** se consume. |
| Superficie válida | Animación de enganche → el servidor comprueba que el jugador sigue teniendo el objeto, lo consume y empieza el rappel. |
| **W** / **S** | Subir / bajar. Al soltar, el jugador se queda parado en ese punto de la cuerda. |
| **Shift + S** | Bajada rápida deslizándose por la cuerda (`rope_slide`). |
| **Espacio** | Salto contra la pared: se separa y baja 3 m de golpe (`rappel_jump_c`). |
| **F** | Soltarse a mano, solo si quedan 3 m o menos hasta el suelo. |
| **G** (parado) | **Boca abajo** (prototipo): el personaje se gira 180° mirando a la pared. Al moverse, saltar o volver a pulsar G se pone derecho. |
| Llegar arriba o abajo del todo | El rappel termina solo: arriba el jugador queda de pie en la cornisa; abajo suelta la cuerda a 1 m del suelo (`ReleaseHeight`) y cae solo. Si algo falla y atraviesa el suelo, vuelve al punto donde usó la cuerda. |
| Parado en la cuerda | Puede sacar el arma y sigue en postura de colgar con el arma en la mano. Solo mientras apunta o dispara pasa a la pose de apuntar del juego (de pie), y vuelve a colgar al dejar de apuntar. Al moverse se guarda el arma. |

### Detección de superficie (`client/detection.lua`)

Se prueban dos casos, en este orden:

- **Desde abajo (subir):** el jugador mira a una pared. Un rayo hacia delante tiene que encontrar una superficie con inclinación ≤ `MaxWallTilt` respecto a la vertical. Después se escanea hacia arriba, paso a paso, hasta encontrar el borde, y se comprueba que detrás del borde hay una superficie horizontal donde pisar (cornisa o azotea).
- **Desde arriba (bajar):** el jugador está en un borde mirando al vacío. Delante no puede haber obstáculos. Un rayo hacia abajo encuentra el suelo y un rayo desde fuera hacia el edificio comprueba que la pared bajo el borde es vertical.

En los dos casos la altura entre el suelo y el borde tiene que ser ≥ `MinHeight`, para que no se active en un bordillo. Todo se ajusta en `config.lua`.

### Cuerda visual

El servidor avisa a todos los clientes de quién está en rappel y dónde está su anclaje. Cada cliente dibuja la cuerda solo para los jugadores que tiene en rango, y la crea o la borra cuando entran o salen de él. También les llega a los jugadores que se conectan cuando ya hay alguien en la cuerda. Se desactiva con `Config.Rope.Enabled = false`.

## Qué comprobar en el servidor de pruebas

- **Animaciones:** `missrappel` → `rappel_idle` (parado) y `rappel_walk` (subiendo o bajando), y `mp_common_heist` → `rappel_intro` al engancharse desde arriba. Se cambian en `config.lua` sin tocar código. Mientras está en la cuerda, al personaje se le quita la gravedad (`SetPedGravity`) en lugar de congelarlo: congelar a un ped y moverlo cada fotograma lo deja en pose T.
- **Torre de entrenamiento:** si la torre es un prop/ymap y no se detecta, revisa `Config.Detection.Flags` (por defecto mundo + objetos).
- **Disparo en parado:** con el arma en la mano se mantiene la postura de colgar; solo mientras se apunta o dispara (y `AimHold` ms después) se pasa a la pose de apuntar del juego, que es de pie. Para apuntar con las piernas en la pared hace falta una animación propia (Blender/Sollumz) que solo mueva las piernas.
- **Boca abajo (prototipo):** para girar al personaje se engancha a un objeto invisible con rotación (`Config.Invert.Rot`), porque GTA mantiene a los peds siempre derechos. Sin animación propia se ve la postura de colgar girada. Disparar boca abajo está sin probar: la pose de apuntar del juego está pensada para ir de pie.

## Fuera de alcance (MVP)

- Tienda o precio propios.
- Anclajes colocados a mano.
- Postura boca abajo estilo Rainbow Six Siege. Queda para una fase posterior y probablemente necesite una animación `.ycd` hecha en Blender/Sollumz.
