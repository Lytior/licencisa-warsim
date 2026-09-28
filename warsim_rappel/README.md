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
     },
     ```
     ox_inventory respeta los objetos registrados con `ESX.RegisterUsableItem`, así que no hace falta nada más.
3. Añade `cuerda_arnes` al catálogo de la tienda de objetos existente con el precio que corresponda.

No hay restricción de rango: cualquier jugador que tenga el objeto puede usarlo.

## Funcionamiento

| Paso | Qué ocurre |
|---|---|
| Usar el objeto | El servidor pide al cliente que busque una superficie válida. |
| Superficie no válida | Se avisa al jugador y el objeto **no** se consume. |
| Superficie válida | Animación de enganche → el servidor comprueba que el jugador sigue teniendo el objeto, lo consume y empieza el rappel. |
| **W** / **S** | Subir / bajar. Al soltar, el jugador se queda parado en ese punto de la cuerda. |
| Llegar arriba o abajo del todo | El rappel termina solo: arriba el jugador queda de pie en la cornisa y abajo en el suelo. |
| Parado en la cuerda | Puede sacar el arma y disparar con el sistema de armas normal. Al moverse se guarda el arma. |

### Detección de superficie (`client/detection.lua`)

Se prueban dos casos, en este orden:

- **Desde abajo (subir):** el jugador mira a una pared. Un rayo hacia delante tiene que encontrar una superficie con inclinación ≤ `MaxWallTilt` respecto a la vertical. Después se escanea hacia arriba, paso a paso, hasta encontrar el borde, y se comprueba que detrás del borde hay una superficie horizontal donde pisar (cornisa o azotea).
- **Desde arriba (bajar):** el jugador está en un borde mirando al vacío. Delante no puede haber obstáculos. Un rayo hacia abajo encuentra el suelo y un rayo desde fuera hacia el edificio comprueba que la pared bajo el borde es vertical.

En los dos casos la altura entre el suelo y el borde tiene que ser ≥ `MinHeight`, para que no se active en un bordillo. Todo se ajusta en `config.lua`.

### Cuerda visual

El servidor avisa a todos los clientes de quién está en rappel y dónde está su anclaje. Cada cliente dibuja la cuerda solo para los jugadores que tiene en rango, y la crea o la borra cuando entran o salen de él. También les llega a los jugadores que se conectan cuando ya hay alguien en la cuerda. Se desactiva con `Config.Rope.Enabled = false`.

## Qué comprobar en el servidor de pruebas

- **Animaciones:** los nombres de `Config.Anims` (`missrappel` / `rappel_idle`, `mini@repair` / `fixing_a_ped`) hay que verificarlos en juego. Si alguno no gusta o no carga, se cambia en `config.lua` sin tocar código. Si un diccionario no carga en 3 s, se omite la animación y el sistema sigue funcionando.
- **Torre de entrenamiento:** si la torre es un prop/ymap y no se detecta, revisa `Config.Detection.Flags` (por defecto mundo + objetos).
- **Disparo en parado:** mientras el jugador tiene el arma en la mano, se quita la animación de colgar para que funcione el sistema de armas normal, y el personaje gira con la cámara para poder apuntar alrededor. Al guardar el arma vuelve a agarrarse a la cuerda. GTA no tiene una animación nativa de colgar con una mano y disparar con la otra.

## Fuera de alcance (MVP)

- Tienda o precio propios.
- Anclajes colocados a mano.
- Postura boca abajo estilo Rainbow Six Siege. Queda para una fase posterior y probablemente necesite una animación `.ycd` hecha en Blender/Sollumz.
