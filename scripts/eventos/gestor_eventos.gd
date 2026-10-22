class_name GestorEventos
extends Node
## Hace pasar los eventos de caos de una ruta (etapa 5; plan de PlanEventos). Cada evento tiene
## aviso (letrero y pitido unos metros antes), inicio y fin:
## - topes y bache gigante: ya están en la calle; el chofer automático frena solo ante el bache (D3).
## - animales y bloqueo: algo cruza o cierra la calle; el chofer automático frena y espera.
## - lluvia: baja el agarre de las llantas mientras dura y se nubla.
## - prisa: el chofer maneja en modo loco un tramo (conducción variable).
## - carrerita: aparece un camión rival atrás, el chofer se pone loco y el rival, si rebasa, se
##   detiene en la siguiente parada y se lleva a la gente que esperaba.
## - inspector: en la siguiente parada revisa; multa por cada pasajero a bordo sin pagar.
## - robo: en una parada sube un ratero que va tras el morral del cobrador (BotLadron). Si se lo
##   roba y se baja, el dinero se pierde; si lo tumban antes, se le cae en monedas.
## El chofer automático no esquiva: solo frena ante lo que se le marca con `alto_en`.

signal anunciado(evento: Dictionary)
signal empezo(evento: Dictionary)
signal termino(evento: Dictionary)

const RUTA := "res://config/eventos.cfg"
const COLOR_RIVAL := Color(0.85, 0.42, 0.12)

@export var calle: Calle
@export var camion: Camion
@export var piloto: PilotoAutomatico
@export var pasajeros: GestorPasajeros
@export var hud: HudInterior
## Donde se agregan los animales, la valla, el rival, etc.
@export var escenario: Node3D
@export var ambiente: WorldEnvironment
@export var sol: DirectionalLight3D

var eventos: Array[Dictionary] = []
## Tipos que ya empezaron, en orden (para las pruebas y el resultado de la ruta).
var historial: Array[String] = []
## Para las pruebas: el rival y cuántos pasajeros se llevó, y las multas del inspector.
var rival: Camion
var pasajeros_robados: int = 0
var multas: int = 0
## Para las pruebas: el ratero del robo en curso y lo que se llevó en total.
var ladron: BotLadron
var robado: int = 0

var _cfg: ConfigFile
var _indice: int = -1
var _modo_base: PilotoAutomatico.Modo = PilotoAutomatico.Modo.NORMAL
var _lluvia: CPUParticles3D
var _ambiente_original: Dictionary = {}


func _ready() -> void:
	_cfg = Config.archivo_config(RUTA)
	Config.recargado.connect(func(): _cfg = Config.archivo_config(RUTA))
	for evento in eventos:
		evento.estado = "pendiente"


func _physics_process(delta: float) -> void:
	_indice = calle.indice_cercano(camion.global_position, _indice)
	var alto := -1
	var alto_obstaculo := -1
	var tope := -1.0
	var claxon := false
	for evento in eventos:
		if evento.estado == "terminado":
			continue
		if evento.estado == "pendiente" and _toca_avisar(evento):
			evento.estado = "avisado"
			_avisar(evento)
		if evento.estado == "avisado" and _toca_empezar(evento):
			evento.estado = "activo"
			evento.tiempo = 0.0
			historial.append(evento.tipo)
			_empezar(evento)
			empezo.emit(evento)
		if evento.estado in ["avisado", "activo"]:
			var r := _atender(evento, delta)
			if r.has("alto") and (alto < 0 or int(r.alto) < alto):
				alto = r.alto
			if r.has("alto") and evento.tipo != "carrerita" and (alto_obstaculo < 0 or int(r.alto) < alto_obstaculo):
				alto_obstaculo = r.alto
			if r.has("tope"):
				tope = float(r.tope) if tope < 0.0 else minf(tope, r.tope)
			claxon = claxon or r.get("claxon", false)
	piloto.alto_en = alto
	piloto.velocidad_tope = tope
	# El rival tampoco atraviesa animales ni vallas.
	if is_instance_valid(rival):
		(rival.get_node("PilotoRival") as PilotoAutomatico).alto_en = alto_obstaculo
	if claxon:
		camion.comandos.claxon = true


## Metros de calle desde el camión hasta `distancia` (negativo si ya pasó).
func _falta(distancia: float) -> float:
	return distancia - _indice * Calle.PASO


func _toca_avisar(evento: Dictionary) -> bool:
	var aviso: float = _cfg.get_value("general", "aviso", 45.0)
	match evento.tipo:
		"inspector":
			# Con tiempo para cobrarle a todos: desde que sale de la parada anterior.
			return pasajeros.parada_actual < 0 and _falta(evento.inicio) < 160.0
		"carrerita":
			return _falta(evento.inicio) < 2.0
		"robo":
			# Cuando el camión está en la parada donde sube (con tiempo de que se suba).
			return pasajeros.parada_actual == evento.parada
	return _falta(evento.inicio) < aviso


func _toca_empezar(evento: Dictionary) -> bool:
	match evento.tipo:
		"animales", "bloqueo", "carrerita", "inspector", "robo":
			return true
	return _falta(evento.inicio) <= 0.0


func _avisar(evento: Dictionary) -> void:
	hud.anunciar("EVENTO_" + String(evento.tipo).to_upper(), Color(1.0, 0.45, 0.3) if evento.tipo in ["carrerita", "inspector", "robo"] else Color(1.0, 0.85, 0.3))
	anunciado.emit(evento)


func _empezar(evento: Dictionary) -> void:
	var i := calle.indice_en_distancia(evento.inicio)
	match evento.tipo:
		"animales":
			# Salen de la banqueta derecha y cruzan hacia la izquierda.
			var grupo := UtileriaEventos.animales()
			escenario.add_child(grupo)
			var lado := calle.ancho_carril + calle.ancho_banqueta * 0.5
			# La vaca camina hacia su -X local: de la derecha de la calle a la izquierda.
			var derecha := calle.derecha(i)
			grupo.global_transform = Transform3D(Basis(derecha, Vector3.UP, derecha.cross(Vector3.UP)), _en_calle(i, lado))
			evento.nodo = grupo
			evento.lateral = lado
		"bloqueo":
			var valla := UtileriaEventos.valla(calle.ancho_carril * 2.0)
			escenario.add_child(valla)
			valla.global_transform = Transform3D(Basis.looking_at(calle.direcciones[i], Vector3.UP), _en_calle(i, 0.0))
			evento.nodo = valla
			evento.espera = 0.0
		"lluvia":
			camion.factor_agarre = float(_cfg.get_value("lluvia", "agarre", 0.5))
			_lluvia = UtileriaEventos.lluvia()
			camion.add_child(_lluvia)
			_nublar(true)
		"prisa":
			piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
		"carrerita":
			_crear_rival(evento)
			piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
		"robo":
			_subir_ladron(evento)
		"inspector":
			var parada: Dictionary = calle.paradas[evento.parada]
			var figura := UtileriaEventos.inspector()
			escenario.add_child(figura)
			var k: int = parada.indice_poste
			figura.global_transform = Transform3D(Basis.looking_at(-calle.derecha(k), Vector3.UP), parada.poste + calle.direcciones[k] * 1.2 + Vector3.UP * (calle.alto_calle + calle.alto_banqueta))
			evento.nodo = figura
			evento.revisado = false


## Lo que hace cada evento mientras está avisado o activo. Devuelve {alto, tope, claxon}.
func _atender(evento: Dictionary, delta: float) -> Dictionary:
	var r := {}
	if evento.estado == "activo":
		evento.tiempo += delta
	match evento.tipo:
		"topes":
			if _falta(evento.fin) < -6.0:
				_terminar(evento)
		"bache_gigante":
			r.tope = float(_cfg.get_value("bache_gigante", "velocidad_chofer", 25.0)) / 3.6
			if _falta(evento.fin) < -4.0:
				_terminar(evento)
		"animales":
			var grupo: AnimatableBody3D = evento.nodo
			var i := calle.indice_en_distancia(evento.inicio)
			# Empiezan a cruzar cuando el camión se acerca; mientras estén en la calle, el chofer frena.
			if _falta(evento.inicio) < 30.0:
				evento.lateral -= float(_cfg.get_value("animales", "rapidez", 1.3)) * delta
				grupo.global_position = _en_calle(i, evento.lateral)
			if evento.lateral > -(calle.ancho_carril + 1.5):
				r.alto = i - 8
			elif _falta(evento.inicio) < -20.0:
				_terminar(evento)
		"bloqueo":
			var i := calle.indice_en_distancia(evento.inicio)
			if is_instance_valid(evento.nodo):
				r.alto = i - 7
				# Con el camión detenido frente a la valla, cuenta la espera y pita.
				if _falta(evento.inicio) < 16.0 and absf(camion.velocidad_adelante) < 0.5:
					evento.espera += delta
					r.claxon = fmod(evento.espera, 2.0) < 0.5
				if evento.espera > float(_cfg.get_value("bloqueo", "espera", 6.0)):
					evento.nodo.queue_free()
					hud.mensaje(tr("MSJ_BLOQUEO_FIN"), Color(0.7, 1.0, 0.6))
			elif _falta(evento.inicio) < -10.0:
				_terminar(evento)
		"lluvia":
			if _lluvia != null:
				_lluvia.global_position = camion.global_position + Vector3.UP * 9.0 - camion.global_basis.z * 6.0
			if _falta(evento.fin) < 0.0:
				camion.factor_agarre = 1.0
				if _lluvia != null:
					_lluvia.queue_free()
					_lluvia = null
				_nublar(false)
				hud.mensaje(tr("MSJ_LLUVIA_FIN"), Color(0.8, 0.9, 1.0))
				_terminar(evento)
		"prisa":
			if _falta(evento.fin) < 0.0:
				_volver_al_modo_base(evento)
				hud.mensaje(tr("MSJ_PRISA_FIN"), Color(0.8, 0.9, 1.0))
				_terminar(evento)
		"carrerita":
			r = _atender_carrerita(evento)
		"robo":
			# Termina cuando el ratero se fue (con o sin el botín).
			if not is_instance_valid(evento.get("bot")):
				ladron = null
				_terminar(evento)
		"inspector":
			if pasajeros.parada_actual == evento.parada:
				evento.en_parada = float(evento.get("en_parada", 0.0)) + delta
				if not evento.revisado and evento.en_parada > float(_cfg.get_value("inspector", "retraso", 3.0)):
					evento.revisado = true
					_revisar(evento)
			elif evento.revisado:
				if is_instance_valid(evento.nodo):
					evento.nodo.queue_free()
				_terminar(evento)
	return r


## Carrerita: el rival va por el carril izquierdo hasta rebasar; luego se mete al derecho y se
## detiene en la parada disputada. Si el camión llega primero, el rival se sigue de largo.
func _atender_carrerita(evento: Dictionary) -> Dictionary:
	var r := {}
	if not is_instance_valid(rival):
		_volver_al_modo_base(evento)
		_terminar(evento)
		return r
	var piloto_rival: PilotoAutomatico = rival.get_node("PilotoRival")
	var i_rival := calle.indice_cercano(rival.global_position, int(evento.get("i_rival", -1)))
	evento.i_rival = i_rival
	var adelante := i_rival - _indice
	# Rebasa por la izquierda; ya bien adelante, se mete a su carril.
	piloto_rival.carril = 0 if adelante > 14 else 1
	# Nadie choca de frente con el de adelante en el mismo carril: el de atrás frena.
	if piloto_rival.carril == 0 and adelante > 0 and adelante < 40:
		r.alto = i_rival - 11
	if not evento.get("decidida", false):
		if pasajeros.parada_actual == evento.parada:
			evento.decidida = true
			piloto_rival.detenerse_en_paradas = false
			hud.mensaje(tr("MSJ_RIVAL_GANAMOS"), Color(0.6, 1.0, 0.5))
			_volver_al_modo_base(evento)
		elif piloto_rival.parada_actual == evento.parada:
			evento.decidida = true
			var se_fueron := pasajeros.llevarse_esperando(evento.parada, rival.global_transform * Vector3(2.0, 0.0, -3.0))
			pasajeros_robados += se_fueron
			hud.mensaje(tr("MSJ_RIVAL_SE_LLEVO") % se_fueron, Color(1.0, 0.5, 0.4))
			_volver_al_modo_base(evento)
	# Después de su parada, el rival ya no se detiene en ninguna otra.
	if evento.get("decidida", false) and piloto_rival.parada_actual < 0:
		piloto_rival.detenerse_en_paradas = false
	# Ya decidida y el rival se fue lejos (o ya no avanza): desaparece.
	evento.tiempo_rival = float(evento.get("tiempo_rival", 0.0)) + get_physics_process_delta_time()
	var lejos := adelante > 90 or i_rival > calle.puntos.size() - 25 or adelante < -60
	if (evento.get("decidida", false) and lejos) or evento.tiempo_rival > 90.0:
		rival.queue_free()
		rival = null
		_volver_al_modo_base(evento)
		_terminar(evento)
	return r


func _crear_rival(evento: Dictionary) -> void:
	var escena: PackedScene = load("res://escenas/camion/camion.tscn")
	rival = escena.instantiate()
	rival.name = "Rival"
	rival.con_sonido = false
	rival.get_node("Carroceria").color_principal = COLOR_RIVAL
	rival.get_node("Carroceria").con_interior = false
	var camara := rival.get_node("Carroceria/CamaraChofer")
	camara.get_parent().remove_child(camara)
	camara.free()
	rival.get_node("Carroceria/Letrero").text = "LETRERO_RIVAL"
	escenario.add_child(rival)
	var atras := maxi(1, _indice - roundi(float(_cfg.get_value("carrerita", "aparece_atras", 35.0)) / Calle.PASO))
	rival.colocar(calle.transform_en_indice(atras, 1))
	rival.linear_velocity = camion.linear_velocity
	ChoferSentado.sentar_en(rival, "chofer")
	var p := PilotoAutomatico.new()
	p.name = "PilotoRival"
	p.camion = rival
	p.pista = calle
	p.carril = 1
	p.factor_velocidad = float(_cfg.get_value("carrerita", "factor_rival", 1.2))
	p.espera_fija = float(_cfg.get_value("carrerita", "espera_rival", 4.0))
	p.respetar_terminal = false
	rival.add_child(p)
	p.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	evento.i_rival = atras


## El ratero aparece en la banqueta junto a la puerta y sube como cualquier pasajero.
func _subir_ladron(evento: Dictionary) -> void:
	var interior: InteriorCamion = escenario.get("interior")
	var ragdolls: GestorRagdolls = escenario.get("ragdolls")
	var bot := BotLadron.new()
	bot.name = "Ladron"
	bot.pasajeros = pasajeros
	bot.ragdolls = ragdolls
	bot.cobrador = escenario.get("cobrador")
	bot.parada_subida = evento.parada
	bot.alcance = float(_cfg.get_value("robo", "alcance", 0.9))
	var cuerpo := BotInterior.nuevo_cuerpo("Ladron", "ladron")
	var afuera := camion.global_transform * (GestorPasajeros.PUERTA_AFUERA + Vector3(1.2, 0.0, 1.0))
	interior.agregar_en_calle(cuerpo, null, Transform3D(Basis(), afuera + Vector3.UP * 0.05))
	cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
	cuerpo.atravesar_personajes(true)
	ragdolls.vigilar(cuerpo)
	bot.cuerpo = cuerpo
	bot.puesto = Vector3(0.0, -0.28, 0.5)
	escenario.add_child(bot)
	bot.subir_por_la_puerta()
	bot.robo.connect(func(monto): hud.mensaje(tr("MSJ_ROBO") % monto, Color(1.0, 0.45, 0.35)))
	bot.se_le_cayo.connect(func(monto): hud.mensaje(tr("MSJ_ROBO_CAYO") % monto, Color(0.6, 1.0, 0.5)))
	bot.se_fue.connect(func(monto):
		if monto > 0:
			robado += monto
			hud.mensaje(tr("MSJ_ROBO_SE_FUE") % monto, Color(1.0, 0.45, 0.35)))
	evento.bot = bot
	ladron = bot


## El inspector revisa: multa por cada pasajero a bordo sin pagar.
func _revisar(evento: Dictionary) -> void:
	var sin_pagar := pasajeros.sin_pagar_a_bordo()
	if sin_pagar == 0:
		hud.mensaje(tr("MSJ_INSPECTOR_LIMPIO"), Color(0.6, 1.0, 0.5))
		return
	var multa := sin_pagar * int(_cfg.get_value("inspector", "multa_por_pasajero", 12))
	var cobrada := Juego.penalizar(multa)
	multas += cobrada
	hud.mensaje(tr("MSJ_INSPECTOR_MULTA") % [sin_pagar, cobrada], Color(1.0, 0.5, 0.4))
	evento.multa = cobrada


func _terminar(evento: Dictionary) -> void:
	evento.estado = "terminado"
	termino.emit(evento)


## Al terminar la prisa o la carrerita, el chofer regresa a como venía (si no sigue otra).
func _volver_al_modo_base(evento: Dictionary) -> void:
	if evento.get("modo_devuelto", false):
		return
	evento.modo_devuelto = true
	for otro in eventos:
		if otro != evento and otro.tipo in ["prisa", "carrerita"] and otro.estado == "activo" and not otro.get("modo_devuelto", false):
			return
	piloto.cambiar_modo(_modo_base)


func _nublar(nublado: bool) -> void:
	if ambiente == null or sol == null:
		return
	var e := ambiente.environment
	if nublado:
		_ambiente_original = {"sol": sol.light_energy, "luz": e.ambient_light_energy, "niebla": e.fog_density}
		sol.light_energy *= 0.45
		e.ambient_light_energy *= 0.75
		e.fog_density *= 6.0
	elif not _ambiente_original.is_empty():
		sol.light_energy = _ambiente_original.sol
		e.ambient_light_energy = _ambiente_original.luz
		e.fog_density = _ambiente_original.niebla


## Punto sobre el asfalto en la muestra i, desplazado `lateral` metros a la derecha del centro.
func _en_calle(i: int, lateral: float) -> Vector3:
	return calle.puntos[i] + calle.derecha(i) * lateral + Vector3.UP * calle.alto_calle
