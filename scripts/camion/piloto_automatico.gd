class_name PilotoAutomatico
extends Node
## Maneja el camión por la calle de prueba para poder caminar adentro (etapa 2).
## Sigue el carril derecho, baja la velocidad antes de las curvas y, según el modo, mete
## "sustos": frenazos, acelerones y volantazos de golpe. Es el borrador del bot chofer (etapa 5).
## Solo escribe en camion.comandos, como cualquier chofer.

enum Modo { PARADO, TRANQUILO, NORMAL, LOCO }
const NOMBRES := {Modo.PARADO: "parado", Modo.TRANQUILO: "tranquilo", Modo.NORMAL: "normal", Modo.LOCO: "loco"}

signal susto(tipo: String)

@export var camion: Camion
@export var pista: PistaPrueba
@export var modo: Modo = Modo.NORMAL

var parametros: ParametrosInterior
var _indice: int = -1
var _azar := RandomNumberGenerator.new()
var _tiempo_para_susto: float = 5.0
var _susto: String = ""
var _tiempo_susto: float = 0.0
var _volantazo: float = 0.0


func _ready() -> void:
	process_physics_priority = -10
	parametros = ParametrosInterior.cargar()
	Config.recargado.connect(func(): parametros = ParametrosInterior.cargar())
	_azar.randomize()


func cambiar_modo(nuevo: Modo) -> void:
	modo = nuevo
	_susto = ""
	_tiempo_para_susto = _intervalo_sustos() * _azar.randf_range(0.5, 1.0)


## Después de mover el camión a mano, buscar de nuevo dónde está.
func reiniciar() -> void:
	_indice = -1


func _intervalo_sustos() -> float:
	if modo == Modo.PARADO:
		return 0.0
	return float(parametros.piloto[NOMBRES[modo]][2])


func _physics_process(delta: float) -> void:
	var c := camion.comandos
	c.limpiar()
	if modo == Modo.PARADO:
		c.frenar = 1.0 if camion.velocidad_adelante > 0.3 else 0.0
		return
	var datos: Array = parametros.piloto[NOMBRES[modo]]
	var velocidad_objetivo: float = datos[0] / 3.6
	var lateral: float = datos[1]

	_indice = pista.indice_cercano(camion.global_position, _indice)
	var n := pista.puntos.size()
	var velocidad := camion.velocidad_adelante
	var adelante := roundi(7.0 + maxf(velocidad, 0.0) * 0.6)
	var objetivo := pista.puntos[(_indice + adelante) % n] + pista.derecha(_indice + adelante) * pista.ancho_carril * 0.5
	var local := camion.global_transform.affine_inverse() * objetivo
	c.girar = clampf(atan2(local.x, -local.z) * 2.2, -1.0, 1.0)

	var giro_adelante := 0.0
	for k in range(5, 35, 5):
		giro_adelante = maxf(giro_adelante, pista.direcciones[(_indice + k) % n].angle_to(pista.direcciones[(_indice + k + 5) % n]))
	velocidad_objetivo = minf(velocidad_objetivo, sqrt(lateral * 5.0 / maxf(giro_adelante, 0.001)))
	if velocidad < velocidad_objetivo - 0.5:
		c.acelerar = 1.0
	elif velocidad > velocidad_objetivo + 1.5:
		c.frenar = clampf((velocidad - velocidad_objetivo) / 5.0, 0.2, 1.0)
	else:
		c.acelerar = 0.35

	_sustos(delta, c)


## De vez en cuando, algo de golpe: frenazo, acelerón o volantazo. Cada uno dura un momento.
func _sustos(delta: float, c: ComandosConduccion) -> void:
	var intervalo := _intervalo_sustos()
	if intervalo <= 0.0:
		return
	if _susto == "":
		_tiempo_para_susto -= delta
		if _tiempo_para_susto <= 0.0 and camion.velocidad_adelante > 5.0:
			_susto = ["frenazo", "frenazo", "aceleron", "volantazo"][_azar.randi() % 4]
			_tiempo_susto = {"frenazo": _azar.randf_range(0.6, 1.3), "aceleron": 1.5, "volantazo": 0.35}[_susto]
			_volantazo = [-1.0, 1.0][_azar.randi() % 2] * 0.6
			susto.emit(_susto)
		return
	_tiempo_susto -= delta
	match _susto:
		"frenazo":
			c.acelerar = 0.0
			c.frenar = 1.0
		"aceleron":
			c.acelerar = 1.0
			c.frenar = 0.0
		"volantazo":
			c.girar = clampf(c.girar + _volantazo, -1.0, 1.0)
	if _tiempo_susto <= 0.0:
		_susto = ""
		_tiempo_para_susto = intervalo * _azar.randf_range(0.6, 1.4)
