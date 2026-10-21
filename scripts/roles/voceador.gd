class_name Voceador
extends Node
## Rol de voceador (DISEÑO.md, secciones 5.1 y 10.1; etapa 6A) para un personaje (jugador o bot).
## Va en la puerta y grita la ruta: manteniendo "gritar" gasta aliento y, cerca de una parada,
## junta gente que se acerca a la puerta (GestorPasajeros). Con la acción del rol jala al
## siguiente que espera para que suba ya. Este es el grito por teclado; el del micrófono es la 6D.
## Si no va sujeto, un frenazo lo saca.
##
## Colgado de la puerta (D55): con la puerta abierta, "sentarse" en la puerta lo cuelga del tubo,
## asomado hacia afuera con la mano estirada (y otra vez lo baja). Así, con el camión andando, su
## acción jala al que hace la parada a medio camino: sube al vuelo y deja un bono, más grande
## entre más rápido vaya el camión. Si va demasiado rápido se le resbala y el pasajero sale
## rodando. Colgado, un golpe fuerte del camión lo avienta a la calle.

signal ayudo
signal recogio(bono: int)
signal se_le_resbalo

## Colgado: los pies en el borde del escalón, junto al tubo de la puerta; viendo hacia afuera y un
## poco al frente, se asoma hacia allá y estira la mano libre hacia adelante y abajo (coordenadas
## del camión). Al bajarse vuelve a su puesto.
const COLGADO_EN := Vector3(1.3, GestorPasajeros.PISO, -2.85)
const MIRA_HACIA := Vector3(1.0, 0.0, -0.6)
const HACIA_AFUERA := Vector3(1.0, 0.0, -0.35)
const MANO_AFUERA := Vector3(2.4, 0.35, -3.9)
const AL_BAJARSE := Vector3(1.05, GestorPasajeros.PISO, -2.8)

## Si el rol pasa a otra persona (rotación de "Tírame paro"), la que estaba colgada se baja.
@export var cuerpo: CuerpoPersonaje:
	set(valor):
		if cuerpo != valor and cuerpo != null and is_instance_valid(cuerpo) and cuerpo.colgado:
			_bajar(cuerpo)
		cuerpo = valor
@export var pasajeros: GestorPasajeros

## Aliento de 0 a 100.
var aliento: float = 100.0
## Si en este cuadro le está saliendo el grito.
var gritando: bool = false
## Totales para la interfaz y las pruebas.
var segundos_gritados: float = 0.0
var total_ayudados: int = 0
var total_recogidos: int = 0
var total_bonos: int = 0
var total_resbalados: int = 0

var _roles: ParametrosRoles
var _sonido: AudioStreamPlayer


func _ready() -> void:
	# Antes que el gestor de pasajeros: así "sentarse" en la puerta lo cuelga en vez de buscar asiento.
	process_physics_priority = -5
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

	if c.sentarse and (cuerpo.colgado or puede_colgarse()):
		c.sentarse = false
		if cuerpo.colgado:
			_bajar(cuerpo)
		else:
			_colgar()
	# Si cierran la puerta, se mete.
	if cuerpo.colgado and not pasajeros.interior.puerta_abierta:
		_bajar(cuerpo)

	if c.accion_rol:
		c.accion_rol = false
		if cuerpo.colgado and pasajeros.parada_actual < 0:
			_recoger()
		elif junto_a_la_puerta() and pasajeros.ayudar_a_subir():
			total_ayudados += 1
			ayudo.emit()


## Si puede colgarse de la puerta: está parado junto a ella y está abierta.
func puede_colgarse() -> bool:
	if cuerpo == null or cuerpo.desplomado or cuerpo.sentado or not pasajeros.interior.esta_dentro(cuerpo) or not pasajeros.interior.puerta_abierta:
		return false
	return pasajeros.interior.posicion_local(cuerpo).distance_to(COLGADO_EN) < _roles.alcance_colgarse


## Dónde va su mano estirada, en el mundo (para ver a quién alcanza).
func mano_en_el_mundo() -> Vector3:
	return pasajeros.interior.camion.global_transform * MANO_AFUERA


func _colgar() -> void:
	cuerpo.umbral_soltarse = _roles.umbral_soltarse
	cuerpo.colgarse(Transform3D(Basis.looking_at(MIRA_HACIA, Vector3.UP), COLGADO_EN), HACIA_AFUERA)
	cuerpo.mano_afuera = MANO_AFUERA


func _bajar(quien: CuerpoPersonaje) -> void:
	quien.pararse(Transform3D(quien.global_basis, AL_BAJARSE + Vector3.UP * 0.02))


## Jala al que hace la parada a medio camino, si lo alcanza.
func _recoger() -> void:
	var bono := pasajeros.recoger_al_paso(mano_en_el_mundo(), _roles.alcance_recoger, _roles.recoger_maxima, _roles.bono_recoger)
	if bono > 0:
		total_recogidos += 1
		total_bonos += bono
		Juego.ingresar(bono)
		recogio.emit(bono)
	elif bono < 0:
		total_resbalados += 1
		se_le_resbalo.emit()


## Si está en la puerta, donde alcanza a jalar a la gente que sube.
func junto_a_la_puerta() -> bool:
	if cuerpo.desplomado:
		return false
	var local := pasajeros.interior.posicion_local(cuerpo)
	return local.distance_to(GestorPasajeros.PUERTA_UMBRAL) < _roles.alcance_ayuda
