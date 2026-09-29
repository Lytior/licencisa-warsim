# warsim_mobiliario: sillas y camas interactivas

Recurso independiente (no necesita ESX ni otro framework). Convierte en interactivos los
modelos de silla y de cama que aparecen en `config.lua`, tanto los del mapa como los que
coloquéis vosotros (ymap, CodeWalker, props creados por script).

## Instalación

1. Copia la carpeta `warsim_mobiliario` dentro de `resources/` del servidor.
2. En `server.cfg` añade:
   ```
   ensure warsim_mobiliario
   ```
3. Reinicia el servidor (o `refresh` y `ensure warsim_mobiliario` en la consola).

## Uso en el juego

| Acción | Cómo |
|---|---|
| Sentarse en una silla | Acércate (menos de 1,8 m) y pulsa **E**. El jugador se coloca en el asiento y hace la animación de sentarse (`PROP_HUMAN_SEAT_CHAIR_MP_PLAYER`). |
| Tumbarse en una cama | Acércate y pulsa **E**. El jugador se coloca encima y se tumba boca arriba (`anim@gangops@morgue@table@` / `body_search`). |
| Levantarse | Vuelve a pulsar **E**. |

Cada jugador puede cambiar la tecla en *Ajustes > Asignación de teclas > FiveM*; el texto
de ayuda muestra siempre la tecla que tenga asignada.

- Una silla o cama solo la puede usar un jugador a la vez (lo controla el servidor).
- Si el jugador muere, entra en un vehículo, le empujan fuera de la silla o se borra el
  mueble, se levanta solo y el mueble queda libre.

## Curación en las camas

Mientras el jugador está tumbado:

- **Vida:** recupera `Config.Cura.VidaPorTick` puntos cada `Config.Cura.Intervalo` ms
  hasta el máximo (por defecto 5 por segundo, unos 20 s de 100 a 200).
- **Heridas:** a los `Config.Cura.TiempoHeridas` segundos (10 por defecto) se le quitan la
  sangre y el daño visible del personaje, y se lanzan los eventos de `Config.EventosHeridas`.

Si el servidor usa un sistema de heridas o de ambulancia, añadid su evento de curación a
`Config.EventosHeridas` para que la cama también le quite las heridas de ese sistema:

```lua
Config.EventosHeridas = {
    { evento = 'esx_ambulancejob:heal', args = { 'big', true } },
}
```

Además, el script lanza el evento de cliente `warsim_mobiliario:heridasCuradas`, por si
otro recurso lo quiere escuchar.

## Añadir más sillas o camas

Añade el nombre del modelo a `Config.Sillas` o `Config.Camas` en `config.lua`:

```lua
Config.Sillas = {
    ['prop_chair_01a'] = { z = 0.5, heading = 180.0 },
    ['mi_silla_addon'] = { z = 0.45, heading = 180.0 },
}
```

- `z`: altura a la que se coloca al jugador respecto al origen del modelo.
- `heading`: giro respecto al mueble. Si el jugador queda mirando al respaldo o con la
  cabeza a los pies de la cama, cambia `180.0` por `0.0` (o `90.0` / `-90.0`).
- `atras` (opcional): desplaza al jugador hacia delante (+) o hacia atrás (−) del mueble.

## Qué comprobar en el servidor de pruebas

Los valores de `z` y `heading` son los habituales para estos modelos, pero no se han
probado uno a uno en el juego. Hay que revisar sobre todo:

- **Camas bajas** (`gr_prop_bunker_bed_01`, `gr_prop_gr_campbed_01`, camas de casa): la
  animación tumba al personaje a la altura de una camilla de hospital, así que en camas
  bajas puede quedar flotando. Se arregla poniendo una `z` negativa (por ejemplo `-0.4`).
- **Sillas de oficina y bancos**: si el jugador queda hundido o flotando, ajusta `z`.
