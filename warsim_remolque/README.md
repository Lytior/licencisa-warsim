# warsim_remolque: remolque de artillería

![Anti-Aircraft Trailer](foto/trailersmall2.png)

- **Nombre en GTA:** Anti-Aircraft Trailer (del DLC Gunrunning)
- **Nombre de spawn / modelo:** `trailersmall2`
- Viene con el juego, así que **no hace falta hacer stream de ningún archivo**.
- Para disparar, un jugador se sube al remolque (asiento del artillero) y controla el cañón.

## Instalación en el servidor FiveM

1. Copia la carpeta `warsim_remolque` dentro de `resources/` del servidor
   (por ejemplo `resources/[warsim]/warsim_remolque`).
2. En `server.cfg` añade:
   ```
   ensure warsim_remolque

   # Quién puede sacar/borrar el remolque con comando
   add_ace group.admin warsim.remolque allow
   ```
   Si quieres que lo pueda sacar cualquiera, pon `Config.UsarPermisos = false` en `config.lua`.
3. Reinicia el servidor (o usa `refresh` y `ensure warsim_remolque` en la consola).

## Uso en el juego

| Acción | Cómo |
|---|---|
| Sacar el remolque detrás de ti | `/remolque` |
| Borrar tu remolque | `/borrarremolque` |
| Saber si tu vehículo tiene punto de enganche | `/comprobarenganche` |
| Enganchar / desenganchar | Súbete como conductor, da marcha atrás hasta que el enganche quede a menos de 4 m del morro del remolque y pulsa **H** |

Cada jugador puede cambiar la tecla en *Ajustes > Asignación de teclas > FiveM*.

## Elegir a qué vehículos se puede enganchar

Abre `config.lua` y edita la lista `Config.VehiculosPermitidos` con los **nombres de spawn**
de los vehículos que queráis:

```lua
Config.VehiculosPermitidos = {
    'insurgent',
    'barracks',
    'mesa3',
    'mitanque',   -- también sirven vehículos addon, con su nombre de spawn
}
```

- Solo esos vehículos pueden engancharlo, ya sea con la tecla o dando marcha atrás como
  hace GTA por defecto. A los demás se les suelta automáticamente.
- Si pones `Config.PermitirTodos = true`, cualquier vehículo podrá engancharlo.
- Si un vehículo no tiene punto de enganche en su modelo, el script pega el remolque detrás
  de forma rígida para que se pueda llevar igualmente.
- Si queréis que el script controle otros remolques, añadidlos a `Config.Remolques`
  (por ejemplo `'trailersmall'`, `'boattrailer'`, `'trailers4'`).

## Punto de enganche

El punto de enganche es un **hueso (bone) del modelo 3D** llamado `attach_male`, colocado
en la parte trasera del vehículo. El remolque tiene el suyo en la lanza, llamado `attach_female`.
GTA une el remolque por esos dos puntos. Si el vehículo no tiene `attach_male`, GTA no puede
engancharlo de forma normal.

### Cómo saber si lo tiene
- **En el juego:** súbete al vehículo y escribe `/comprobarenganche`. Te dice si lo tiene y,
  si lo tiene, marca con una flecha roja dónde está durante 10 segundos.
- **En OpenIV / CodeWalker:** abre el `.yft` del vehículo y busca `attach_male` en la lista
  de huesos (Skeleton / Bones).

### Cómo ponérselo a un vehículo que no lo tiene
Hay que editar el modelo. Solo tiene sentido en vehículos addon o en vehículos que ya reemplacéis por stream.
1. Saca el `.yft` del vehículo con OpenIV (o cógelo de la carpeta `stream` del addon).
2. Ábrelo en **Blender con Sollumz** (gratis) o en **ZModeler 3**.
3. Añade un hueso o dummy llamado exactamente `attach_male` como hijo del hueso `chassis`,
   y colócalo en la parte trasera, donde iría la bola de remolque (centrado y a la altura
   del enganche del remolque).
4. Exporta el `.yft` (y el `_hi.yft` si lo tiene) y ponlo en la carpeta `stream` del recurso
   del vehículo.
5. Reinicia el recurso y comprueba con `/comprobarenganche`.

Si no queréis tocar el modelo, no pasa nada. Este script engancha igualmente el remolque de
forma rígida a los vehículos de `Config.VehiculosPermitidos` que no tengan el punto. La única
diferencia es que el remolque no gira en las curvas como uno de verdad.
