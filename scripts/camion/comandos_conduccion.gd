class_name ComandosConduccion
extends RefCounted
## Lo que el chofer le pide al camión en un cuadro de física.
## Lo llena quien maneje (jugador local, bot o, más adelante, la red); el camión solo lee esto.

## Pedal del acelerador, de 0 a 1.
var acelerar: float = 0.0
## Pedal del freno, de 0 a 1. Con el camión casi detenido, mete reversa.
var frenar: float = 0.0
## Volante, de -1 (izquierda) a 1 (derecha).
var girar: float = 0.0
## Claxon presionado.
var claxon: bool = false
## Pide enderezar el camión sobre la calle (se consume al usarse).
var reiniciar: bool = false
## Abrir o cerrar la puerta (se consume al usarse; lo atiende la escena).
var puerta: bool = false


## Suelta pedales, volante y claxon. No toca `reiniciar`, que lo consume el camión.
func limpiar() -> void:
	acelerar = 0.0
	frenar = 0.0
	girar = 0.0
	claxon = false
