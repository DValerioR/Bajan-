class_name ComandosPersonaje
extends RefCounted
## Lo que un personaje quiere hacer en un cuadro de física. Lo llena el jugador local
## (EntradaJugador), un bot o, más adelante, la red; CuerpoPersonaje solo lee esto.

## Dirección de caminar: x = derecha, y = adelante, cada uno de -1 a 1.
var mover := Vector2.ZERO
## Cuánto girar la vista en este cuadro (grados): x = horizontal, y = vertical.
var mirar := Vector2.ZERO
## Mantener presionado para sujetarse del pasamanos.
var sujetarse: bool = false
## Pulsaciones (se consumen al usarse).
var saltar: bool = false
var agarrar: bool = false
var accion: bool = false
## Cobrar el pasaje (cobrador).
var cobrar: bool = false
## Sentarse en el asiento libre más cercano, o pararse si ya va sentado.
var sentarse: bool = false
