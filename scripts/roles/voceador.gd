class_name Voceador
extends Node
## Rol de voceador (DISEÑO.md, secciones 5.1 y 10.1; etapa 6A) para un personaje (jugador o bot).
## Va en la puerta y grita la ruta: manteniendo "gritar" gasta aliento y, cerca de una parada,
## junta gente que se acerca a la puerta (GestorPasajeros). Con la acción del rol jala al
## siguiente que espera para que suba ya. Este es el grito por teclado; el del micrófono es la 6D.
## Lo de ir colgado de la puerta lo pone la física: si no va sujeto, un frenazo lo saca.

signal ayudo

@export var cuerpo: CuerpoPersonaje
@export var pasajeros: GestorPasajeros

## Aliento de 0 a 100.
var aliento: float = 100.0
## Si en este cuadro le está saliendo el grito.
var gritando: bool = false
## Totales para la interfaz y las pruebas.
var segundos_gritados: float = 0.0
var total_ayudados: int = 0

var _roles: ParametrosRoles
var _sonido: AudioStreamPlayer


func _ready() -> void:
	_roles = ParametrosRoles.cargar()
	Config.recargado.connect(func(): _roles = ParametrosRoles.cargar())
	_sonido = AudioStreamPlayer.new()
	_sonido.name = "Grito"
	_sonido.stream = Sintetizador.grito()
	_sonido.volume_db = -8.0
	add_child(_sonido)


func _physics_process(delta: float) -> void:
	# Sin cuerpo: el rol va de una persona a otra (rotación de "Tírame paro").
	if cuerpo == null or not is_instance_valid(cuerpo):
		gritando = false
		_sonido.stop()
		return
	var c := cuerpo.comandos
	var quiere := c.gritar and not cuerpo.desplomado
	# Sin aliento no sale: hay que juntar un poco antes de volver a empezar.
	var puede := aliento > (0.0 if gritando else _roles.aliento_minimo)
	gritando = quiere and puede
	if gritando:
		aliento = maxf(0.0, aliento - _roles.gasto_aliento * delta)
		segundos_gritados += delta
		pasajeros.gritando = true
	else:
		aliento = minf(100.0, aliento + _roles.recupera_aliento * delta)
	if cuerpo.visual != null:
		cuerpo.visual.gritar(gritando)
	if gritando != _sonido.playing:
		if gritando:
			_sonido.play()
		else:
			_sonido.stop()

	if c.accion_rol:
		c.accion_rol = false
		if junto_a_la_puerta() and pasajeros.ayudar_a_subir():
			total_ayudados += 1
			ayudo.emit()


## Si está en la puerta, donde alcanza a jalar a la gente que sube.
func junto_a_la_puerta() -> bool:
	if cuerpo.desplomado:
		return false
	var local := pasajeros.interior.posicion_local(cuerpo)
	return local.distance_to(GestorPasajeros.PUERTA_UMBRAL) < _roles.alcance_ayuda
