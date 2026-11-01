# Prompt – Script de contrabando FiveM (WarSync / Operation Warsim)

## Rol y contexto
Eres un desarrollador experto de FiveM (Lua, framework ESX, ox_inventory, NUI con HTML/CSS/JS). Crea un recurso completo llamado `warsync_smuggling` para un servidor de rol militar llamado WarSync (Operation Warsim). El objetivo es dar contenido de rol a la facción Civiles / Prensa, que craftea y vende objetos de contrabando a los soldados de todas las facciones.

## Entorno técnico
- Framework: ESX (`exports['es_extended']:getSharedObject()`).
- Inventario: ox_inventory. Entrega las definiciones de los ítems listas para pegar en `ox_inventory/data/items.lua`, con pesos (en gramos), labels y descripciones. Todos los ítems llevan `consume = 0` y `server = { export = 'warsync_smuggling.useItem' }`: el script valida y quita los ítems en el servidor; ox nunca los quita por su cuenta.
- La comunicación entre jugadores ya existe por radio: NO hagas teléfono ni radio.
- Solo los jugadores con el trabajo de Civiles / Prensa pueden craftear. El nombre del trabajo es configurable (`Config.CivilianJobs = { ['civilian'] = true }`).
- La venta es totalmente manual entre jugadores: el vendedor pone el precio y el dinero se entrega en mano. NO añadas precios, tiendas ni ningún sistema de pago.
- Cualquier soldado de cualquier facción puede comprar y usar los ítems.
- No hace falta SQL.

## Estilo de la interfaz
Toda la interfaz (barra de progreso, menú de crafteo, tableta, notificaciones) debe verse lo mejor posible: moderna, limpia, pulida, con animaciones suaves. Usa NUI (un único `html/index.html` + `style.css` + `app.js`). Estética militar oscura con acento ámbar, notificaciones tipo toast arriba a la derecha y barra de progreso abajo en el centro.

## Mesa de crafteo
- Es un objeto que coloca un admin donde quiera con el comando `/smuggletable add | remove | list` (grupos de admin configurables en `Config.AdminGroups`). Las mesas se guardan en `data/tables.json`, y también se pueden definir mesas fijas en la config.
- Solo los civiles ven el aviso de interacción ("E para abrir") y el blip en el mapa.
- Todos los ítems se craftean en esta mesa. No hacen falta ingredientes: craftear solo cuesta tiempo.
- Cada ítem tarda unos 2 minutos (120 s), mostrado con una barra de progreso moderna. Se cancela pulsando X, al morir o al alejarse de la mesa, y en ese caso se pierde todo el progreso.
- El menú muestra tarjetas con el nombre, la descripción, el nivel de rareza (common / rare / epic / legendary), el tiempo y el peso, y tiene un buscador.
- El servidor valida el trabajo, la distancia a la mesa y que haya pasado el tiempo completo.
- Todo (tiempo de crafteo, lista de ítems, trabajo, modelo de la mesa) es configurable.

## Ítems

1. **Lanzacohetes de racimo de contrabando** (ítem estrella) y **pack de cohetes de racimo**: son dos ítems separados, los dos muy pesados (25 kg y 8 kg).
   - Al usar el lanzador empieza una precarga larga (25 s) que gasta 1 pack de cohetes. Luego el jugador lleva en la mano `WEAPON_RPG` con el disparo nativo bloqueado. Al apretar el gatillo se piden permisos al servidor, y si los da sale una ráfaga de 5 cohetes con dispersión.
   - Cada impacto provoca una explosión muy fuerte (tipo TANKSHELL con escala de daño alta) y deja una zona en llamas durante unos segundos (explosiones de molotov repetidas).
   - El servidor aplica daño extra a los vehículos cercanos, también a los blindados. Lo envía al dueño de red de cada vehículo.
   - Teledirigido opcional hacia el objetivo más cercano al punto de mira (activable en la config).

2. **Binoculares térmicos**: se sostienen en la mano (escenario `WORLD_HUMAN_BINOCULARS`) y dan visión térmica mientras miras. Ratón para mirar, rueda para zoom, Retroceso para bajarlos. No se gastan.

3. **Gafas térmicas**: más caras y deseadas que los binoculares (reflejarlo en la descripción y en el nivel de rareza).
   - Son un ítem que se **equipa como un chaleco**: lo usas desde el inventario para ponértelas (se muestra un prop de casco configurable) y lo vuelves a usar para quitártelas. Las manos quedan libres.
   - Con las gafas puestas, la tecla **L** (reasignable con `RegisterKeyMapping`) enciende y apaga la visión térmica. Sin las gafas, la L no hace nada.
   - **Duran 1 hora real.** El tiempo se gasta mientras están puestas (encendidas o apagadas) y se pausa al quitártelas.
   - El tiempo restante se guarda en la metadata del ítem (`timeLeft` en segundos y `durability` de 0 a 100 para la barra de ox), así que se conserva al venderlas, al desconectarse y al reiniciar el servidor. El servidor guarda el tiempo cada 60 s.
   - Al llegar a 0 se rompen y se eliminan del inventario, con un aviso. Si el jugador las suelta o las da mientras las lleva puestas, se le quitan automáticamente.

4. **Mina normal**: se coloca en el suelo con una vista previa que muestra el radio de activación (E para colocar). Tiene un tiempo de armado y al activarse explota con un daño parecido al de un cohete, afectando a personas y vehículos.

5. **Mina EMP**: más cara que la normal. Cuando un vehículo pasa por encima, lo inutiliza 10 segundos (motor apagado, sin control) sin destruirlo.

6. **Sensor de proximidad**: un dispositivo fijo en el suelo. Cuando alguien entra en su radio (configurable), pita para todos los que estén cerca y envía una notificación en pantalla al dueño. Otros jugadores pueden desactivarlo (E más una barra de progreso), y el dueño puede recogerlo y recuperar el ítem.

7. **Tableta detectora de movimiento**: un overlay en pantalla que no molesta. El jugador puede seguir moviéndose, disparando y actuando con normalidad.
   - Tiene un botón de encendido y apagado. Al mantener ALT izquierdo aparece un cursor (`SetNuiFocus` + `SetNuiFocusKeepInput`), y mientras se mantiene se bloquean el disparo, el cuerpo a cuerpo, el apuntado y la cámara. Así, pulsar el botón NO dispara, NO da golpes y NO mueve la cámara.
   - Al encenderla empieza un temporizador visible de 1 minuto (se pausa si la apagas).
   - Mientras está encendida, el servidor detecta a los enemigos en movimiento cercanos (radio configurable; enemigo = jugador con otro trabajo) y los muestra en una pantalla tipo radar con barrido, orientada según la cámara.
   - Cuando acaba el minuto, la tableta se rompe y se elimina del inventario.

8. **Alcohol** (una botella): al consumirlo solo aplica los efectos típicos de borrachera (pantalla que se tambalea, forma de andar, etc.). Es solo para rol.

9. **Tres drogas ficticias**, cada una con duración y fuerza del efecto configurables:
   - Recreativa: visión borrosa y andar torpe (con alguna caída ocasional), solo por diversión y rol.
   - De resistencia: más velocidad al correr y recuperación de resistencia mucho más rápida durante un tiempo limitado.
   - De salud: aumenta la vida máxima del jugador durante un tiempo limitado.
   - No se puede volver a tomar la misma mientras el efecto siga activo.

## Entregables
- El recurso completo: `fxmanifest.lua`, `config.lua`, `client/` (main, crafting, items, devices, tablet, launcher), `server/` (main, crafting, devices, tablet, launcher, items), `html/` (NUI), `data/tables.json` y `install/ox_items.lua`.
- Comentarios claros en el código y un `README.md` con una guía de instalación corta.
- Todos los valores de balance (daño, duraciones, radios, tiempo de crafteo, tiempo de las gafas, tecla L) en `config.lua`; los pesos en `install/ox_items.lua`.

## Notas para el desarrollador
- Optimiza el rendimiento: poco consumo de resmon y bucles con espera adaptativa (que no trabajen cuando el jugador está lejos).
- Valida todo en el servidor para evitar exploits: crafteo, precarga y disparo, colocación y activación de dispositivos, tiempo de la tableta, tiempo de las gafas, y cualquier ítem que se quite. Usa siempre las posiciones del servidor, nunca las que envía el cliente.
- Los dispositivos colocados pueden guardarse solo en memoria (desaparecen al reiniciar).
- No añadas funciones que no estén en esta lista sin preguntar.
