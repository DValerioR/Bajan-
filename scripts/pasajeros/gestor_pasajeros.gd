class_name GestorPasajeros
extends Node
## Pasajeros no jugables (etapa 3): aparecen en las paradas, suben cuando el camión se detiene
## frente a su parada, buscan asiento o se quedan de pie sujetos del pasamanos, y bajan en su
## parada de destino (unos cuantos en cada parada, nunca todos; DISEÑO.md, sección 6.0).
## Cada pasajero es un CuerpoPersonaje normal: recibe empujones, cae como ragdoll y puede salir
## volando. Si termina en la calle sin haber llegado a su destino, se pierde y se va.
## El "cerebro" de cada uno es una máquina de estados sencilla que llena sus ComandosPersonaje.
##
## Pasaje (etapa 4): cada quien sube sin pagar y trae un "$" encima hasta que el cobrador le
## cobra. El que se baja (o sale volando) sin haber pagado es dinero perdido. Ventana de parada
## (D20): si el camión se queda más de la cuenta, los de a bordo se desesperan, pagan menos y
## alguno se baja enojado sin pagar. En una ruta abierta nadie va más allá de la terminal, y ahí
## se bajan todos.
##
## Roles (etapa 6A): solo suben y bajan con la puerta abierta. El grito del voceador junta gente
## en la parada y la acerca a la puerta; "ayudar a subir" deja pasar al siguiente de inmediato.
## El vendedor le ofrece dulce a cada pasajero una vez.

enum Estado { ESPERANDO, SUBIENDO, CAMINANDO, SENTADO, DE_PIE, BAJANDO, ALEJANDOSE }

const RUTA := "res://config/pasajeros.cfg"
## Puntos de la puerta en coordenadas del camión: abajo de los escalones, en el umbral y ya adentro.
const PUERTA_AFUERA := Vector3(2.85, -0.95, -3.15)
const PUERTA_UMBRAL := Vector3(1.25, -0.3, -3.15)
const PUERTA_ADENTRO := Vector3(0.15, -0.3, -2.85)
const PISO := -0.3
## Lugares para ir de pie, a lo largo del pasillo, en dos filas (el pasillo es de dos personas).
const LUGARES_DE_PIE := [-1.7, -0.5, 0.7, 1.9, 3.1]
const FILAS_DE_PIE := [-0.3, 0.3]
## Por qué lado del pasillo caminan hacia su asiento (no por el centro, para dejar pasar).
const CARRIL_PASILLO := 0.35
const LLEGADA := 0.35
## Asiento del chofer (los pasajeros no lo usan): dónde va sentado quien maneja, y el punto del
## pasillo junto al volante donde se para al dejarlo (coordenadas del camión).
const ASIENTO_CHOFER := Vector3(-0.85, PISO, -2.68)
const JUNTO_AL_VOLANTE := Vector3(-0.3, PISO, -2.7)

signal subio(cuerpo: CuerpoPersonaje)
signal bajo(cuerpo: CuerpoPersonaje)
signal se_perdio(cuerpo: CuerpoPersonaje)
signal cobrado(cuerpo: CuerpoPersonaje, monto: int)
signal bajo_sin_pagar(cuerpo: CuerpoPersonaje, monto: int)
## Cambió quién va al volante (null = nadie).
signal volante_cambio(cuerpo: CuerpoPersonaje)

@export var interior: InteriorCamion
@export var ragdolls: GestorRagdolls
@export var pista: Calle

## Parada donde está detenido el camión (con la puerta frente al poste), o -1.
var parada_actual: int = -1
## Si llega gente nueva a las paradas con el tiempo (las pruebas lo apagan).
var llegadas_activas: bool = true
var pasajeros: Array[Pasajero] = []
## Jugadores que pueden sentarse en los asientos libres (D44). Cada uno: cuerpo -> su lugar.
var jugadores: Dictionary = {}
## Quién va sentado al volante (jugador o bot), o null.
var al_volante: CuerpoPersonaje
## Lo decide la escena según los roles: si este cuerpo puede tomar el volante, y si lo puede dejar,
## con su acción de sentarse. Sin decir nada, nadie puede.
var puede_manejar: Callable
var puede_dejar_volante: Callable
## Totales para las pruebas y la interfaz.
var total_subieron: int = 0
var total_bajaron: int = 0
var total_perdidos: int = 0
var total_sin_pagar: int = 0
var total_atraidos: int = 0
var total_ayudados: int = 0
## Si alguien gritó la ruta en este cuadro (lo pone el voceador; se consume cada cuadro).
var gritando: bool = false
## Segundos de más en la ventana de parada (rotación de "Tírame paro").
var ventana_extra: float = 0.0
## Segundos que lleva el camión en la parada actual y qué tan desesperada está la gente (0 a 1).
var tiempo_en_parada: float = 0.0
var desesperacion: float = 0.0

var _azar := RandomNumberGenerator.new()
var _cfg: ConfigFile
var _lugares: Array[Dictionary] = []
var _turno_puerta: float = 0.0
var _tiempo_llegadas: float = 0.0
var _contador: int = 0
var _roles := ParametrosRoles.new()
## Por parada: segundos de grito juntados y pasajeros que ya llegaron por el grito.
var _grito_juntado: Dictionary = {}
var _atraidos: Dictionary = {}
## Segundos desde el último grito (la gente que espera se acerca a la puerta un rato).
var _desde_grito: float = INF


class Pasajero:
	var cuerpo: CuerpoPersonaje
	var estado: Estado = Estado.ESPERANDO
	var origen: int = -1
	var destino: int = -1
	var lugar: Dictionary = {}
	var ruta: Array[Vector3] = []
	var espera_poste := Vector3.ZERO
	var tiempo: float = 0.0
	var pagado: bool = false
	## Ya se le ofreció dulce (se le ofrece una vez).
	var ofrecido: bool = false
	## Lo jaló el voceador: sube más rápido.
	var jalado: bool = false
	var marca: Label3D
	## Al alejarse: a dónde camina (INF = lejos de la puerta del camión).
	var ir_a := Vector3.INF


func _ready() -> void:
	_azar.randomize()
	_cfg = Config.archivo_config(RUTA)
	_roles = ParametrosRoles.cargar()
	Config.recargado.connect(func():
		_cfg = Config.archivo_config(RUTA)
		_roles = ParametrosRoles.cargar())
	_armar_lugares()
	ragdolls.levantado.connect(_al_levantarse)
	var inicial: Array = _cfg.get_value("pasajeros", "esperando_al_inicio", [1, 3])
	for k in pista.paradas.size():
		if _es_terminal(k):
			continue
		for _i in _azar.randi_range(inicial[0], inicial[1]):
			_aparecer_en_parada(k)


## En una ruta abierta, la última parada es la terminal: ahí no sube nadie y se bajan todos.
func _es_terminal(k: int) -> bool:
	return not pista.cerrada and k == pista.paradas.size() - 1


## Le cobra el pasaje a este pasajero (si va a bordo y no ha pagado). Devuelve lo que pagó.
func cobrar(cuerpo: CuerpoPersonaje) -> int:
	for p in pasajeros:
		if p.cuerpo != cuerpo or p.pagado or not _a_bordo(p):
			continue
		var monto := maxi(1, roundi(Juego.parametros.pasaje * (1.0 - 0.5 * desesperacion)))
		p.pagado = true
		cobrado.emit(cuerpo, monto)
		return monto
	return 0


## El pasajero sin pagar más cercano a `desde`, hacia donde se mira, dentro del alcance (en el
## espacio del interior). Lo usa el cobrador.
func por_cobrar_cerca(desde: Vector3, mirada: Vector3, alcance: float) -> CuerpoPersonaje:
	return _cerca_que(desde, mirada, alcance, func(p: Pasajero): return not p.pagado)


## El pasajero a bordo más cercano al que todavía no se le ofrece dulce (lo usa el vendedor).
func por_vender_cerca(desde: Vector3, mirada: Vector3, alcance: float) -> CuerpoPersonaje:
	return _cerca_que(desde, mirada, alcance, func(p: Pasajero): return not p.ofrecido)


## Le ofrece dulce a este pasajero (una sola vez). Devuelve la propina, o 0 si no quiso.
func vender(cuerpo: CuerpoPersonaje) -> int:
	for p in pasajeros:
		if p.cuerpo != cuerpo or p.ofrecido or not _a_bordo(p):
			continue
		p.ofrecido = true
		if _azar.randf() >= _roles.probabilidad_compra:
			return 0
		return _azar.randi_range(int(_roles.propina[0]), int(_roles.propina[1]))
	return 0


## Pasajeros a bordo (adentro, sin estar tirados) que cumplen `filtro`: "sin_pagar" o "sin_ofrecer".
## Para los bots del interior.
func a_bordo_que(filtro: String) -> Array[CuerpoPersonaje]:
	var lista: Array[CuerpoPersonaje] = []
	for p in pasajeros:
		if not _a_bordo(p) or p.estado == Estado.BAJANDO or p.cuerpo.desplomado or not interior.esta_dentro(p.cuerpo):
			continue
		if (filtro == "sin_pagar" and not p.pagado) or (filtro == "sin_ofrecer" and not p.ofrecido):
			lista.append(p.cuerpo)
	return lista


## Dónde pararse para atender a un pasajero, en coordenadas del camión: frente a su asiento si
## va sentado; si va de pie, junto a él.
func punto_para_atender(cuerpo: CuerpoPersonaje) -> Vector3:
	for p in pasajeros:
		if p.cuerpo == cuerpo and p.cuerpo.sentado and not p.lugar.is_empty():
			return p.lugar.pasillo
	return interior.posicion_local(cuerpo)


func _cerca_que(desde: Vector3, mirada: Vector3, alcance: float, filtro: Callable) -> CuerpoPersonaje:
	var mejor: CuerpoPersonaje = null
	var mejor_puntaje := INF
	for p in pasajeros:
		if not filtro.call(p) or not _a_bordo(p) or p.cuerpo.desplomado or not interior.esta_dentro(p.cuerpo):
			continue
		var hacia := p.cuerpo.global_position + Vector3.UP * p.cuerpo.altura * 0.6 - desde
		var distancia := hacia.length()
		if distancia > alcance:
			continue
		var alineado := hacia.normalized().dot(mirada)
		if alineado < 0.2:
			continue
		var puntaje := distancia * (2.0 - alineado)
		if puntaje < mejor_puntaje:
			mejor_puntaje = puntaje
			mejor = p.cuerpo
	return mejor


func _a_bordo(p: Pasajero) -> bool:
	return p.estado in [Estado.CAMINANDO, Estado.SENTADO, Estado.DE_PIE, Estado.BAJANDO]


## El voceador jala al siguiente que espera en esta parada: sube de inmediato y más rápido.
## Devuelve true si había a quién ayudar.
func ayudar_a_subir() -> bool:
	if parada_actual < 0 or not interior.puerta_abierta or not _hay_lugar():
		return false
	for p in pasajeros:
		if p.estado == Estado.ESPERANDO and p.origen == parada_actual and not p.jalado:
			p.jalado = true
			_turno_puerta = 0.0
			total_ayudados += 1
			return true
	return false


## La parada donde se oye el grito: en la que está el camión o la siguiente, si ya está cerca.
func parada_que_oye() -> int:
	if parada_actual >= 0:
		return parada_actual if not _es_terminal(parada_actual) else -1
	var puerta := interior.camion.global_transform * PUERTA_UMBRAL
	var adelante := -interior.camion.global_basis.z
	var mejor := -1
	var mejor_distancia := _roles.alcance_grito
	for k in pista.paradas.size():
		if _es_terminal(k):
			continue
		var hacia: Vector3 = pista.paradas[k].poste - puerta
		hacia.y = 0.0
		# Solo las de adelante.
		if hacia.dot(adelante) < 0.0:
			continue
		if hacia.length() < mejor_distancia:
			mejor_distancia = hacia.length()
			mejor = k
	return mejor


func _atender_grito(delta: float) -> void:
	var grito := gritando
	gritando = false
	_desde_grito = 0.0 if grito else _desde_grito + delta
	if not grito:
		return
	var k := parada_que_oye()
	if k < 0:
		return
	_grito_juntado[k] = float(_grito_juntado.get(k, 0.0)) + delta
	if _grito_juntado[k] >= _roles.segundos_por_pasajero and int(_atraidos.get(k, 0)) < _roles.max_atraidos_por_parada:
		_grito_juntado[k] = 0.0
		if _aparecer_en_parada(k, true):
			_atraidos[k] = int(_atraidos.get(k, 0)) + 1
			total_atraidos += 1


## Sustos y llegadas repetibles (para las pruebas automáticas).
func fijar_semilla(semilla: int) -> void:
	_azar.seed = semilla


func a_bordo() -> int:
	var cuenta := 0
	for p in pasajeros:
		if p.estado in [Estado.CAMINANDO, Estado.SENTADO, Estado.DE_PIE]:
			cuenta += 1
	return cuenta


## Si todavía hay gente subiendo o bajando (el chofer espera un poco más).
func hay_movimiento_en_puerta() -> bool:
	for p in pasajeros:
		if p.estado == Estado.BAJANDO:
			return true
		if p.estado == Estado.SUBIENDO or (p.estado == Estado.ESPERANDO and p.origen == parada_actual and _hay_lugar()):
			return true
	return false


# --- Lugares en el camión ---------------------------------------------------

func _armar_lugares() -> void:
	_lugares.clear()
	var carroceria := GeometriaInterior.Carroceria
	for z in carroceria.FILAS_ASIENTOS:
		for x in carroceria.X_ASIENTOS:
			_lugares.append({"asiento": true, "punto": Vector3(x, PISO, z - 0.02), "pasillo": Vector3(CARRIL_PASILLO * signf(x), PISO, z), "ocupado": null})
	for z in LUGARES_DE_PIE:
		for x in FILAS_DE_PIE:
			_lugares.append({"asiento": false, "punto": Vector3(x, PISO, z), "pasillo": Vector3(x, PISO, z), "ocupado": null})


func _hay_lugar() -> bool:
	return a_bordo() + _contar(Estado.SUBIENDO) < int(_cfg.get_value("pasajeros", "capacidad", 15))


func _reservar_lugar(p: Pasajero) -> void:
	var libres := _lugares.filter(func(l): return l.ocupado == null)
	if libres.is_empty():
		return
	# Prefieren asiento; si no hay, de pie.
	var asientos := libres.filter(func(l): return l.asiento)
	var elegido: Dictionary = asientos[_azar.randi() % asientos.size()] if not asientos.is_empty() else libres[_azar.randi() % libres.size()]
	elegido.ocupado = p
	p.lugar = elegido


func _liberar_lugar(p: Pasajero) -> void:
	if not p.lugar.is_empty():
		p.lugar.ocupado = null
		p.lugar = {}


func _contar(estado: Estado) -> int:
	return pasajeros.filter(func(p): return p.estado == estado).size()


# --- Aparecer y desaparecer ------------------------------------------------

## Aparece un pasajero esperando en la parada k. `por_grito`: llegó porque oyó al voceador (no
## cuenta para el máximo de los que esperan). Devuelve true si apareció.
func _aparecer_en_parada(k: int, por_grito: bool = false) -> bool:
	var esperando := pasajeros.filter(func(p): return p.estado == Estado.ESPERANDO and p.origen == k).size()
	if esperando >= int(_cfg.get_value("pasajeros", "max_esperando_por_parada", 4)) and not por_grito:
		return false
	if pasajeros.size() >= int(_cfg.get_value("pasajeros", "max_total", 30)):
		return false
	var p := Pasajero.new()
	p.origen = k
	var viaje: Array = _cfg.get_value("pasajeros", "paradas_de_viaje", [1, 3])
	p.destino = k + _azar.randi_range(viaje[0], viaje[1])
	p.destino = p.destino % pista.paradas.size() if pista.cerrada else mini(p.destino, pista.paradas.size() - 1)
	var i: int = pista.paradas[k].indice_poste
	var a_lo_largo: Vector3 = pista.direcciones[i]
	p.espera_poste = pista.paradas[k].poste + a_lo_largo * _azar.randf_range(-2.0, 2.5) + pista.derecha(i) * _azar.randf_range(0.2, 1.2)

	var cuerpo := CuerpoPersonaje.new()
	_contador += 1
	cuerpo.name = "Pasajero%d" % _contador
	cuerpo.parametros = interior.parametros
	var visual := Personaje.new()
	visual.name = "Visual"
	var modelos: Array = _cfg.get_value("pasajeros", "modelos", ["galan"])
	visual.modelo = modelos[_azar.randi() % modelos.size()]
	cuerpo.add_child(visual)
	cuerpo.visual = visual
	p.cuerpo = cuerpo
	_poner_marca(p)
	interior.agregar_en_calle(cuerpo, null, Transform3D(Basis.looking_at(-pista.derecha(i), Vector3.UP), p.espera_poste + Vector3.UP * 0.05))
	cuerpo.configurar(visual.altura, visual.altura_ojos)
	cuerpo.orientar(cuerpo.giro_actual())
	cuerpo.atravesar_personajes(true)
	ragdolls.vigilar(cuerpo)
	pasajeros.append(p)
	return true


## Los que esperan en la parada k se van con otro camión (el rival de la carrerita): caminan
## hacia `hacia` y desaparecen. Devuelve cuántos se fueron.
func llevarse_esperando(k: int, hacia: Vector3) -> int:
	var cuantos := 0
	for p in pasajeros:
		if p.estado == Estado.ESPERANDO and p.origen == k:
			p.estado = Estado.ALEJANDOSE
			p.ir_a = hacia
			p.tiempo = 0.0
			cuantos += 1
	return cuantos


## Pasajeros a bordo que todavía no pagan (para el inspector).
func sin_pagar_a_bordo() -> int:
	return pasajeros.filter(func(p): return _a_bordo(p) and not p.pagado).size()


## Quita a todos los pasajeros (para pruebas que necesitan el camión vacío).
func vaciar() -> void:
	for p in pasajeros.duplicate():
		_desaparecer(p)


## Quita a los que esperan en las paradas.
func vaciar_paradas() -> void:
	for p in pasajeros.duplicate():
		if p.estado == Estado.ESPERANDO:
			_desaparecer(p)


# --- Jugadores en los asientos (D44) ------------------------------------------

## Deja que este jugador se siente en los asientos libres con su comando `sentarse`.
func agregar_jugador(cuerpo: CuerpoPersonaje) -> void:
	jugadores[cuerpo] = {}


## El asiento libre más cercano a `pies` (coordenadas del camión) a menos de `alcance`, o {}.
func asiento_libre_cerca(pies: Vector3, alcance: float) -> Dictionary:
	var mejor := {}
	var mejor_distancia := alcance
	for l in _lugares:
		if not l.asiento or l.ocupado != null:
			continue
		var distancia := Vector2(pies.x - l.punto.x, pies.z - l.punto.z).length()
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			mejor = l
	return mejor


## Sienta a este cuerpo al volante (si está libre). Devuelve true si se sentó.
func sentar_al_volante(cuerpo: CuerpoPersonaje) -> bool:
	if al_volante != null or cuerpo.desplomado or not interior.esta_dentro(cuerpo):
		return false
	# Al volante solo va quien tiene el rol de chofer (si la escena lo dice).
	if puede_manejar.is_valid() and not puede_manejar.call(cuerpo):
		return false
	if jugadores.has(cuerpo) and not jugadores[cuerpo].is_empty():
		jugadores[cuerpo].ocupado = null
		jugadores[cuerpo] = {}
	var punto := ASIENTO_CHOFER
	punto.y = PISO + 0.45 - cuerpo.visual.altura_cadera
	cuerpo.sentarse(Transform3D(Basis(), punto))
	al_volante = cuerpo
	volante_cambio.emit(cuerpo)
	return true


## Lo para del volante, en el pasillo junto al asiento del chofer.
func dejar_volante(cuerpo: CuerpoPersonaje) -> void:
	if al_volante != cuerpo:
		return
	al_volante = null
	if cuerpo.sentado:
		cuerpo.pararse(Transform3D(cuerpo.global_basis, JUNTO_AL_VOLANTE + Vector3.UP * 0.02))
	volante_cambio.emit(null)


## Si está parado junto al volante, donde alcanza a sentarse.
func cerca_del_volante(cuerpo: CuerpoPersonaje) -> bool:
	var aqui := interior.posicion_local(cuerpo)
	return Vector2(aqui.x - ASIENTO_CHOFER.x, aqui.z - ASIENTO_CHOFER.z).length() < interior.parametros.alcance_asiento


func _atender_volante() -> void:
	# Si el que manejaba ya no va sentado (lo recolocaron, lo quitaron), el volante queda libre.
	if al_volante != null and (not is_instance_valid(al_volante) or not al_volante.sentado):
		al_volante = null
		volante_cambio.emit(null)


func _atender_jugadores() -> void:
	_atender_volante()
	for cuerpo: CuerpoPersonaje in jugadores.keys():
		if not is_instance_valid(cuerpo):
			jugadores.erase(cuerpo)
			continue
		var lugar: Dictionary = jugadores[cuerpo]
		# Si ya no está sentado (cayó como ragdoll, lo recolocaron), el asiento queda libre.
		if not lugar.is_empty() and not cuerpo.sentado:
			lugar.ocupado = null
			jugadores[cuerpo] = {}
			lugar = {}
		if not cuerpo.comandos.sentarse:
			continue
		cuerpo.comandos.sentarse = false
		if al_volante == cuerpo:
			if puede_dejar_volante.is_valid() and puede_dejar_volante.call(cuerpo):
				dejar_volante(cuerpo)
			continue
		if lugar.is_empty() and puede_manejar.is_valid() and puede_manejar.call(cuerpo) and cerca_del_volante(cuerpo):
			sentar_al_volante(cuerpo)
			continue
		if not lugar.is_empty():
			# Se para en el pasillo, frente a su asiento.
			lugar.ocupado = null
			jugadores[cuerpo] = {}
			cuerpo.pararse(Transform3D(cuerpo.global_basis, lugar.pasillo + Vector3.UP * 0.02))
			continue
		if cuerpo.desplomado or not cuerpo.en_suelo or not interior.esta_dentro(cuerpo):
			continue
		var libre := asiento_libre_cerca(cuerpo.global_position, interior.parametros.alcance_asiento)
		if libre.is_empty():
			continue
		libre.ocupado = cuerpo
		jugadores[cuerpo] = libre
		var punto: Vector3 = libre.punto
		punto.y = PISO + 0.45 - cuerpo.visual.altura_cadera
		cuerpo.sentarse(Transform3D(Basis(), punto))


## Sube de golpe a `cuantos` pasajeros ya acomodados en sus lugares (para pruebas de rendimiento).
func llenar(cuantos: int) -> void:
	for _i in cuantos:
		var p := Pasajero.new()
		_reservar_lugar(p)
		if p.lugar.is_empty():
			return
		p.origen = -1
		p.destino = _azar.randi() % pista.paradas.size()
		var cuerpo := CuerpoPersonaje.new()
		_contador += 1
		cuerpo.name = "Pasajero%d" % _contador
		cuerpo.parametros = interior.parametros
		var visual := Personaje.new()
		visual.name = "Visual"
		var modelos: Array = _cfg.get_value("pasajeros", "modelos", ["galan"])
		visual.modelo = modelos[_azar.randi() % modelos.size()]
		cuerpo.add_child(visual)
		cuerpo.visual = visual
		p.cuerpo = cuerpo
		_poner_marca(p)
		interior.agregar(cuerpo, null, Transform3D(Basis(), p.lugar.pasillo + Vector3.UP * 0.02))
		cuerpo.configurar(visual.altura, visual.altura_ojos)
		cuerpo.atravesar_personajes(true)
		ragdolls.vigilar(cuerpo)
		pasajeros.append(p)
		p.estado = Estado.CAMINANDO
		p.ruta = [p.lugar.pasillo]


## "$" sobre la cabeza de quien va a bordo sin pagar (cuelga de su figura, así se ve adentro).
func _poner_marca(p: Pasajero) -> void:
	var marca := Label3D.new()
	marca.name = "MarcaSinPagar"
	marca.text = "$"
	marca.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	marca.font_size = 96
	marca.pixel_size = 0.004
	marca.outline_size = 18
	marca.modulate = Color(0.45, 1.0, 0.35)
	marca.outline_modulate = Color(0.05, 0.2, 0.05)
	marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marca.no_depth_test = true
	marca.position = Vector3(0.0, 2.1, 0.0)
	marca.visible = false
	p.cuerpo.visual.add_child(marca)
	p.marca = marca


func _desaparecer(p: Pasajero) -> void:
	_liberar_lugar(p)
	interior.quitar(p.cuerpo)
	p.cuerpo.queue_free()
	pasajeros.erase(p)


# --- Cada cuadro -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var antes := parada_actual
	parada_actual = _detectar_parada()
	_ventana_de_parada(delta, antes)
	_turno_puerta = maxf(0.0, _turno_puerta - delta)
	_atender_grito(delta)
	_atender_jugadores()
	_tiempo_llegadas += delta
	if llegadas_activas and _tiempo_llegadas > float(_cfg.get_value("pasajeros", "intervalo_llegadas", 12.0)):
		_tiempo_llegadas = 0.0
		for k in pista.paradas.size():
			if k != parada_actual and not _es_terminal(k) and _azar.randf() < float(_cfg.get_value("pasajeros", "probabilidad_llegada", 0.5)):
				_aparecer_en_parada(k)
	for p: Pasajero in pasajeros.duplicate():
		if not is_instance_valid(p.cuerpo):
			pasajeros.erase(p)
			continue
		p.tiempo += delta
		if p.marca != null:
			p.marca.visible = _a_bordo(p) and not p.pagado and not p.cuerpo.desplomado
			p.marca.position.y = p.cuerpo.altura + 0.35
		var c: ComandosPersonaje = p.cuerpo.comandos
		c.mover = Vector2.ZERO
		c.sujetarse = false
		if p.cuerpo.desplomado:
			continue
		match p.estado:
			Estado.ESPERANDO:
				_esperar(p)
			Estado.SUBIENDO:
				_subir(p)
			Estado.CAMINANDO:
				_caminar_a_lugar(p)
			Estado.SENTADO, Estado.DE_PIE:
				_viajar(p)
			Estado.BAJANDO:
				_bajar(p)
			Estado.ALEJANDOSE:
				_alejarse(p)


## Cuánto dura la ventana de parada: la de config/partida.cfg más lo que se alargue (la rotación
## de "Tírame paro" le da unos segundos más).
func duracion_ventana() -> float:
	return Juego.parametros.ventana + ventana_extra


## Ventana de parada (D20): pasado el tiempo, la gente se desespera y alguno se baja enojado.
## En la terminal se bajan todos.
func _ventana_de_parada(delta: float, parada_anterior: int) -> void:
	if parada_actual < 0:
		tiempo_en_parada = 0.0
		desesperacion = 0.0
		return
	if parada_actual != parada_anterior:
		tiempo_en_parada = 0.0
		if _es_terminal(parada_actual):
			for p in pasajeros:
				if _a_bordo(p):
					p.destino = parada_actual
	tiempo_en_parada += delta
	var parametros := Juego.parametros
	if tiempo_en_parada <= duracion_ventana():
		return
	desesperacion = minf(1.0, desesperacion + parametros.desesperacion_por_segundo * delta)
	if _azar.randf() < parametros.probabilidad_bajarse * delta:
		var enojados := pasajeros.filter(func(p): return p.estado in [Estado.SENTADO, Estado.DE_PIE] and p.destino != parada_actual)
		if not enojados.is_empty():
			var p: Pasajero = enojados[_azar.randi() % enojados.size()]
			p.destino = parada_actual


## El camión está en una parada si va casi parado y su puerta queda cerca del poste.
func _detectar_parada() -> int:
	var camion := interior.camion
	if absf(camion.velocidad_adelante) > 0.5:
		return -1
	var puerta := camion.global_transform * PUERTA_UMBRAL
	for k in pista.paradas.size():
		var poste: Vector3 = pista.paradas[k].poste
		if Vector2(puerta.x - poste.x, puerta.z - poste.z).length() < 3.5:
			return k
	return -1


func _esperar(p: Pasajero) -> void:
	var puede := parada_actual == p.origen and interior.puerta_abierta and _contar(Estado.BAJANDO) == 0 and _hay_lugar()
	# El que jaló el voceador pasa primero.
	if puede and (_turno_puerta <= 0.0 or p.jalado) and (p.jalado or not _hay_jalado(p.origen)):
		_turno_puerta = float(_cfg.get_value("pasajeros", "separacion_puerta", 0.6))
		_reservar_lugar(p)
		if p.lugar.is_empty():
			return
		p.estado = Estado.SUBIENDO
		p.ruta = [PUERTA_AFUERA, PUERTA_UMBRAL, PUERTA_ADENTRO]
		p.tiempo = 0.0
		return
	# Si el voceador grita con el camión en su parada, se acerca a la puerta.
	if parada_actual == p.origen and _desde_grito < 3.0:
		var junto_a_la_puerta := interior.camion.global_transform * (PUERTA_AFUERA + Vector3(0.9, 0.0, 0.0))
		_caminar_hacia(p, junto_a_la_puerta, 0.9, false)
		return
	# Esperando: se queda junto al poste viendo hacia la calle.
	if _caminar_hacia(p, p.espera_poste, 0.5, false):
		p.cuerpo.comandos.mover = Vector2.ZERO


func _hay_jalado(k: int) -> bool:
	return pasajeros.any(func(o): return o.estado == Estado.ESPERANDO and o.origen == k and o.jalado)


func _subir(p: Pasajero) -> void:
	if interior.esta_dentro(p.cuerpo):
		p.estado = Estado.CAMINANDO
		p.ruta = [PUERTA_ADENTRO, p.lugar.pasillo]
		total_subieron += 1
		subio.emit(p.cuerpo)
		return
	# Si el camión se va sin él, vuelve a esperar.
	if parada_actual != p.origen and p.tiempo > 1.0:
		_liberar_lugar(p)
		p.estado = Estado.ESPERANDO
		return
	_seguir_ruta(p, true, 1.5 if p.jalado else 1.0)


func _caminar_a_lugar(p: Pasajero) -> void:
	if not interior.esta_dentro(p.cuerpo):
		_perderse(p)
		return
	# Para sentarse basta con llegar al pasillo frente a su asiento.
	if _seguir_ruta(p, true):
		if p.lugar.asiento:
			var lugar: Vector3 = p.lugar.punto
			lugar.y = PISO + 0.45 - p.cuerpo.visual.altura_cadera
			p.cuerpo.sentarse(Transform3D(Basis(), lugar))
			p.estado = Estado.SENTADO
		else:
			p.estado = Estado.DE_PIE


func _viajar(p: Pasajero) -> void:
	if not interior.esta_dentro(p.cuerpo) and not p.cuerpo.sentado:
		_perderse(p)
		return
	if parada_actual == p.destino and _turno_puerta <= 0.0 and interior.puerta_abierta:
		_turno_puerta = float(_cfg.get_value("pasajeros", "separacion_puerta", 0.6))
		if p.cuerpo.sentado:
			var pasillo: Vector3 = p.lugar.pasillo
			p.cuerpo.pararse(Transform3D(Basis(), pasillo + Vector3.UP * 0.02))
		_liberar_lugar(p)
		p.estado = Estado.BAJANDO
		p.ruta = [Vector3(0.0, PISO, -2.6), PUERTA_ADENTRO, PUERTA_UMBRAL, PUERTA_AFUERA]
		p.tiempo = 0.0
		return
	if p.estado == Estado.DE_PIE:
		# De pie: sujeto del pasamanos; si el camión lo movió, regresa a su lugar.
		p.cuerpo.comandos.sujetarse = true
		var punto: Vector3 = p.lugar.punto
		if p.cuerpo.global_position.distance_to(punto) > 0.6:
			_caminar_hacia(p, punto, 0.5, true)


func _bajar(p: Pasajero) -> void:
	if not interior.esta_dentro(p.cuerpo):
		p.estado = Estado.ALEJANDOSE
		p.tiempo = 0.0
		total_bajaron += 1
		bajo.emit(p.cuerpo)
		_cobro_perdido(p)
		return
	if _seguir_ruta(p, true) or p.tiempo > 12.0:
		# Si se atoró, ya llegó a la puerta de todos modos: un empujoncito hacia afuera.
		p.ruta = [PUERTA_AFUERA]


func _alejarse(p: Pasajero) -> void:
	var camion := interior.camion
	var lejos := camion.global_transform * (PUERTA_AFUERA + Vector3(4.0, 0.0, 0.0)) if p.ir_a == Vector3.INF else p.ir_a
	_caminar_hacia(p, lejos, 0.8, false)
	if p.tiempo > float(_cfg.get_value("pasajeros", "tiempo_para_desaparecer", 4.0)):
		_desaparecer(p)


func _perderse(p: Pasajero) -> void:
	if _a_bordo(p):
		_cobro_perdido(p)
	_liberar_lugar(p)
	if p.cuerpo.sentado:
		p.cuerpo.pararse(p.cuerpo.global_transform)
	p.estado = Estado.ALEJANDOSE
	p.tiempo = 0.0
	total_perdidos += 1
	se_perdio.emit(p.cuerpo)


## El que se va del camión sin haber pagado es dinero perdido (DISEÑO.md, 6.0).
func _cobro_perdido(p: Pasajero) -> void:
	if p.pagado:
		return
	p.pagado = true
	total_sin_pagar += 1
	bajo_sin_pagar.emit(p.cuerpo, Juego.parametros.pasaje)


## Al levantarse de ser ragdoll: si quedó adentro, regresa a su lugar; si quedó afuera, se perdió.
func _al_levantarse(cuerpo: CuerpoPersonaje) -> void:
	for p in pasajeros:
		if p.cuerpo != cuerpo:
			continue
		if p.estado in [Estado.ESPERANDO, Estado.ALEJANDOSE]:
			return
		if not interior.esta_dentro(cuerpo):
			if p.estado != Estado.SUBIENDO:
				_perderse(p)
			return
		if p.lugar.is_empty():
			_reservar_lugar(p)
		if p.lugar.is_empty():
			return
		if p.estado != Estado.BAJANDO:
			p.estado = Estado.CAMINANDO
			p.ruta = [p.lugar.pasillo]


# --- Caminar ----------------------------------------------------------------

## Sigue sus puntos de ruta (en coordenadas del camión). Devuelve true al terminar.
func _seguir_ruta(p: Pasajero, puntos_del_camion: bool, rapidez: float = 1.0) -> bool:
	while not p.ruta.is_empty():
		var objetivo := p.ruta[0]
		if puntos_del_camion:
			objetivo = interior.desde_local(p.cuerpo, objetivo)
		if not _caminar_hacia(p, objetivo, rapidez, true):
			return false
		p.ruta.remove_at(0)
	return true


## Gira y camina hacia un punto (en el espacio del cuerpo). Devuelve true si ya llegó.
func _caminar_hacia(p: Pasajero, objetivo: Vector3, rapidez: float, girar_rapido: bool) -> bool:
	var cuerpo := p.cuerpo
	var arriba := cuerpo.up_direction
	var diferencia := objetivo - cuerpo.global_position
	diferencia -= arriba * diferencia.dot(arriba)
	if diferencia.length() < LLEGADA:
		cuerpo.comandos.mover = Vector2.ZERO
		return true
	var giro_deseado := atan2(-diferencia.x, -diferencia.z)
	cuerpo.orientar(lerp_angle(cuerpo.giro_actual(), giro_deseado, 0.35 if girar_rapido else 0.15))
	var alineado := clampf(1.0 - absf(angle_difference(cuerpo.giro_actual(), giro_deseado)) / PI, 0.2, 1.0)
	cuerpo.comandos.mover = Vector2(0.0, rapidez * float(_cfg.get_value("pasajeros", "rapidez", 0.8)) * alineado)
	return false
