extends Node
## Estado de la partida en un solo lugar (DISEÑO.md, sección 2): dinero, número de ruta y
## semilla del generador. Vive entre escenas (una ruta, la tiendita, la siguiente ruta).
## La interfaz no lo escribe directo: lo cambian las escenas de juego con estas funciones.

signal dinero_cambio

## Los cuatro roles del camión (DISEÑO.md, sección 5.1).
const ROLES := ["chofer", "cobrador", "voceador", "vendedor"]

var dinero := EstadoDinero.new()
var parametros: ParametrosPartida
## Semilla de la partida: cada ruta usa una derivada, así dos partidas salen distintas.
var semilla_partida: int = 0
var en_partida: bool = false
## Rol del jugador en esta partida. En Modo normal se elige al empezar y no cambia (5.3).
var rol_jugador: String = "cobrador"


func _ready() -> void:
	parametros = ParametrosPartida.cargar()
	Config.recargado.connect(func(): parametros = ParametrosPartida.cargar())


## `rol`: el que eligió el jugador ("azar" = uno al azar; vacío = se queda el que tenía).
func nueva_partida(semilla: int = -1, rol: String = "") -> void:
	parametros = ParametrosPartida.cargar()
	if rol == "azar":
		rol = ROLES[randi() % ROLES.size()]
	if rol in ROLES:
		rol_jugador = rol
	semilla_partida = semilla if semilla >= 0 else randi()
	dinero.empezar_partida(parametros.caja_chica, parametros.bonificacion)
	en_partida = true
	dinero_cambio.emit()


## Prepara la siguiente ruta (cuota más alta cada vez). Devuelve su semilla.
func siguiente_ruta() -> int:
	if not en_partida:
		nueva_partida()
	dinero.empezar_ruta(parametros.cuota_de_ruta(dinero.numero_ruta + 1))
	dinero_cambio.emit()
	return hash([semilla_partida, dinero.numero_ruta])


func ingresar(monto: int) -> void:
	dinero.ingresar(monto)
	dinero_cambio.emit()


func penalizar(monto: int) -> int:
	var cobrado := dinero.penalizar(monto)
	dinero_cambio.emit()
	return cobrado


func pagar_reaparicion() -> bool:
	var pudo := dinero.pagar_reaparicion(parametros.penalizacion_reaparecer)
	dinero_cambio.emit()
	return pudo


## Cierra la ruta. Si no se cumplió la cuota, la partida termina.
func cerrar_ruta() -> bool:
	var cumplida := dinero.cerrar_ruta()
	if not cumplida:
		en_partida = false
	dinero_cambio.emit()
	return cumplida
