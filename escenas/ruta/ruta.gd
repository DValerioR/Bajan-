extends Node3D
## Una ruta completa (etapas 4 a 6B): GeneradorRuta arma la calle por zonas y en el camino pasan
## los eventos de PlanEventos (GestorEventos). Cada rol (chofer, cobrador, voceador, vendedor) lo
## tiene un ocupante: el jugador o un bot, todos con el mismo cuerpo (DISEÑO.md, 5.1 y 5.2). El
## chofer va sentado al volante: si es un bot, maneja el PilotoAutomatico (D42); si es el jugador,
## maneja él. El camión no arranca si nadie va al volante.
## Modo normal: el jugador se queda con su rol. "Tírame paro" (5.3): al llegar a cada parada los
## puestos rotan; nadie se teletransporta, cada quien camina a su nuevo puesto, y la ventana de esa
## parada se alarga un poco. Si al jugador le toca manejar y no se sienta a tiempo, el bot vuelve al
## volante.
## Si el jugador chofer sale volando (o deja el volante) con el camión andando, el camión sigue de
## inercia, la gente se desespera y un bot de a bordo se sienta a manejar; en la siguiente parada se
## cobra "el chofer no entregó el camión" y se resuelve según el modo (5.3, D21).
## La puerta es física: el chofer la abre en las paradas para que suban y bajen; el bot chofer la
## deja abierta al arrancar, como los micros de verdad.
## Al llegar a la terminal se cierra la ruta contra la cuota y se muestra el resultado.
## El estado de la partida (dinero, número de ruta, modo, rol) vive en el autoload Juego.

const ESCENA_MENU := "res://escenas/principal.tscn"
const ESCENA_RUTA := "res://escenas/ruta/ruta.tscn"
## Dónde aparece el jugador: junto a la puerta, mirando hacia el fondo (coordenadas del camión).
const PUESTO_JUGADOR := Vector3(0.35, -0.28, -3.0)
## Puestos de cada rol (coordenadas del camión): el voceador en la puerta, junto al poste.
const PUESTOS := {
	"chofer": GestorPasajeros.JUNTO_AL_VOLANTE,
	"cobrador": Vector3(0.3, -0.28, 0.0),
	"voceador": Vector3(1.05, -0.28, -2.8),
	"vendedor": Vector3(-0.3, -0.28, 1.0),
}
## Modelo de personaje de cada rol.
const MODELOS := {"chofer": "chofer", "cobrador": "cobrador", "voceador": "voceador", "vendedor": "vendedora"}
## Roles del interior (los que camina un personaje).
const ROLES_INTERIOR := ["cobrador", "voceador", "vendedor"]
## Segundos con el camión detenido en la parada antes de que roten los puestos.
const ESPERA_PARA_ROTAR := 1.2
## Segundos fuera del camión (de pie) antes de considerar que se quedó abajo.
const TIEMPO_PARA_QUEDARSE_ABAJO := 1.0

## Para las pruebas: semilla fija de la partida (-1 = al azar).
static var semilla_forzada: int = -1
## Para las pruebas: qué eventos pueden pasar (null = lo que diga config/eventos.cfg).
static var eventos_activos: Variant = null
## Para las pruebas: qué roles del interior cubren bots (null = todos los que no tiene el jugador).
## El chofer siempre tiene a alguien.
static var bots_activos: Variant = null

@onready var camion: Camion = $Camion
@onready var mundo: Node3D = $Mundo
@onready var hud: HudInterior = $Hud

var descripcion: Dictionary
var calle: Calle
var interior: InteriorCamion
var ragdolls: GestorRagdolls
var pasajeros: GestorPasajeros
var piloto: PilotoAutomatico
var eventos: GestorEventos
## "normal" o "paro".
var modo: String = "normal"
## El rol que tiene el jugador ahora.
var rol: String = "cobrador"
var chofer_es_jugador: bool = false
## El cuerpo del jugador.
var jugador: CuerpoPersonaje
## Los nodos de cada rol del interior; su `cuerpo` es quien lo tenga ahora (o null).
var cobrador: Cobrador
var voceador: Voceador
var vendedor: Vendedor
## El bot vendedor (sube y baja en algunas paradas; sin cuerpo mientras no viene a bordo).
var bot_vendedor: BotVendedor
## Bots que cubren cada rol ahora: rol -> su cerebro (BotInterior).
var bots: Dictionary = {}
## Puestos de dulces (coordenadas del mundo).
var puestos: Array[Vector3] = []
## Cuántas veces rotaron los puestos (para la interfaz y las pruebas).
var rotaciones: int = 0
## Veces que el bot tuvo que volver al volante porque el jugador no se sentó.
var volantes_recuperados: int = 0
## Veces que hubo que poner al bot chofer junto al volante porque no llegaba (no debería pasar).
var volantes_rescatados: int = 0
## Veces que un bot de a bordo tuvo que manejar en lugar del chofer jugador, y veces que se cobró
## "el chofer no entregó el camión".
var sustituciones: int = 0
var penalizaciones_chofer: int = 0
var terminada: bool = false
var resultado: Dictionary = {}

var _roles: ParametrosRoles
var _azar := RandomNumberGenerator.new()
## Cerebro de cada bot con cuerpo propio: cuerpo -> BotInterior (el vendedor va aparte).
var _cerebros: Dictionary = {}
## Quién tiene cada rol: rol -> cuerpo (el del vendedor bot se pregunta a bot_vendedor).
var _ocupantes: Dictionary = {}
var _entrada_chofer: EntradaChofer
var _arranque: float = 1.5
var _fuera: float = 0.0
var _esperando_reaparecer: bool = false
var _parada_anterior: int = -1
var _en_terminal: float = 0.0
## Última parada en la que se detuvo el camión (maneje quien maneje).
var _ultima_parada: int = -1
var _paradas_vistas: int = 0
## Rotación de esta parada: el rol que dejó el jugador (para devolverlo si no se sienta al volante).
var _rol_antes_de_rotar: String = ""
var _volante_recuperado_en: int = -1
## Parada donde ya rotaron los puestos: una vez por parada, aunque la detección parpadee (por
## ejemplo, si el camión se mece un poco mientras nadie va al volante).
var _rotada_en: int = -1
var _contador_bots: int = 0
## Bot de a bordo que maneja en lugar del chofer jugador, y el rol que dejó (vacío mientras maneja).
var _sustituto: CuerpoPersonaje
var _rol_del_sustituto: String = ""
## Incidente: el camión anduvo sin su chofer. Se cobra una vez, en la primera parada a la que llega.
var _incidente: bool = false
var _sin_chofer: float = 0.0


func _ready() -> void:
	if not Juego.en_partida:
		Juego.nueva_partida(semilla_forzada)
	modo = Juego.modo
	rol = Juego.rol_jugador
	_roles = ParametrosRoles.cargar()
	_azar.seed = hash([Juego.semilla_partida, Juego.dinero.numero_ruta, "roles"])
	var semilla := Juego.siguiente_ruta()
	descripcion = GeneradorRuta.generar(semilla, Juego.dinero.numero_ruta)
	# "El chofer trae prisa" es del bot chofer: si el jugador maneja (o puede tocarle), no sale.
	var sin_prisa := rol == "chofer" or modo == "paro"
	var plan := PlanEventos.generar(descripcion, semilla, eventos_activos, ["prisa"] if sin_prisa else [])
	PlanEventos.aplicar_a_descripcion(descripcion, plan)

	calle = Calle.new()
	calle.name = "Calle"
	calle.descripcion = descripcion
	add_child(calle)
	move_child(calle, 1)
	camion.colocar(calle.transform_en_indice(calle.indice_en_distancia(4.0)))
	for k in calle.paradas.size():
		if _roles.tiene_puesto(k, calle.paradas.size()):
			puestos.append(calle.poner_puesto_de_dulces(k))

	interior = InteriorCamion.new()
	interior.name = "Interior"
	interior.camion = camion
	interior.mundo = mundo
	add_child(interior)
	interior.fijar_puerta(false)
	ragdolls = GestorRagdolls.new()
	ragdolls.name = "GestorRagdolls"
	ragdolls.interior = interior
	add_child(ragdolls)
	pasajeros = GestorPasajeros.new()
	pasajeros.name = "GestorPasajeros"
	pasajeros.interior = interior
	pasajeros.ragdolls = ragdolls
	pasajeros.pista = calle
	pasajeros.ventana_extra = _roles.segundos_extra_rotacion if modo == "paro" else 0.0
	add_child(pasajeros)
	piloto = PilotoAutomatico.new()
	piloto.name = "PilotoAutomatico"
	piloto.camion = camion
	piloto.pista = calle
	piloto.espera_fija = pasajeros.duracion_ventana()
	piloto.activo = false
	add_child(piloto)
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	piloto.susto.connect(hud.avisar_susto)

	eventos = GestorEventos.new()
	eventos.name = "GestorEventos"
	eventos.eventos = plan
	eventos.calle = calle
	eventos.camion = camion
	eventos.piloto = piloto
	eventos.pasajeros = pasajeros
	eventos.hud = hud
	eventos.escenario = self
	eventos.ambiente = $AmbienteDia/Ambiente
	eventos.sol = $AmbienteDia/Sol
	add_child(eventos)

	_crear_nodos_de_rol()
	pasajeros.volante_cambio.connect(_al_cambiar_volante)
	# Al volante solo se sienta quien tiene el rol de chofer; dejarlo es cosa de la rotación (6B1).
	pasajeros.puede_manejar = func(c): return c == ocupante("chofer")
	pasajeros.puede_dejar_volante = func(_c): return false
	jugador = _crear_jugador()
	for rol_bot in Juego.ROLES:
		if rol_bot == rol:
			continue
		if rol_bot == "chofer" or bots_activos == null or rol_bot in bots_activos:
			_crear_bot_a_bordo(rol_bot)
	_asignar(jugador, rol)
	if rol == "chofer":
		pasajeros.sentar_al_volante(jugador)
	hud.configurar(rol)
	pasajeros.bajo_sin_pagar.connect(func(_c, monto): hud.mensaje(tr("MSJ_SIN_PAGAR") % monto, Color(1.0, 0.5, 0.4)))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Roles y ocupantes ------------------------------------------------------------

## Quién tiene este rol ahora (un cuerpo), o null.
func ocupante(r: String) -> CuerpoPersonaje:
	if r == "chofer" and _sustituto != null and is_instance_valid(_sustituto):
		return _sustituto
	if r == rol:
		return jugador
	if r == "vendedor":
		return bot_vendedor.cuerpo if bot_vendedor.cuerpo != null and is_instance_valid(bot_vendedor.cuerpo) else null
	var c: CuerpoPersonaje = _ocupantes.get(r)
	return c if c != null and is_instance_valid(c) else null


func _crear_nodos_de_rol() -> void:
	cobrador = Cobrador.new()
	cobrador.name = "Cobrador"
	cobrador.pasajeros = pasajeros
	cobrador.ragdolls = ragdolls
	add_child(cobrador)
	voceador = Voceador.new()
	voceador.name = "Voceador"
	voceador.pasajeros = pasajeros
	add_child(voceador)
	vendedor = Vendedor.new()
	vendedor.name = "Vendedor"
	vendedor.pasajeros = pasajeros
	vendedor.ragdolls = ragdolls
	vendedor.puestos = puestos
	add_child(vendedor)
	bot_vendedor = BotVendedor.new()
	bot_vendedor.name = "BotVendedor"
	bot_vendedor.pasajeros = pasajeros
	bot_vendedor.ragdolls = ragdolls
	bot_vendedor.vendedor = vendedor
	bot_vendedor.modelo = MODELOS["vendedor"]
	bot_vendedor.puesto = PUESTOS["vendedor"]
	bot_vendedor.activo = rol != "vendedor" and (bots_activos == null or "vendedor" in bots_activos)
	add_child(bot_vendedor)
	# Lo que le pasa al jugador en su rol se avisa en pantalla.
	cobrador.cobro.connect(func(monto): _avisar_si_jugador(cobrador, tr("MSJ_COBRO") % monto, Color(0.6, 1.0, 0.5)))
	cobrador.se_rego.connect(func(monto): _avisar_si_jugador(cobrador, tr("MSJ_REGO") % monto, Color(1.0, 0.75, 0.3)))
	cobrador.entrego.connect(func(monto): _avisar_si_jugador(cobrador, tr("MSJ_ENTREGA") % monto, Color(0.7, 0.9, 1.0)))
	cobrador.moneda_perdida.connect(func(monto): _avisar_si_jugador(cobrador, tr("MSJ_MONEDA_PERDIDA") % monto, Color(1.0, 0.5, 0.4)))
	voceador.ayudo.connect(func(): _avisar_si_jugador(voceador, tr("MSJ_AYUDO"), Color(0.7, 0.9, 1.0)))
	voceador.recogio.connect(func(bono): _avisar_si_jugador(voceador, tr("MSJ_RECOGIO") % bono, Color(0.6, 1.0, 0.5)))
	voceador.se_le_resbalo.connect(func(): _avisar_si_jugador(voceador, tr("MSJ_SE_RESBALO"), Color(1.0, 0.6, 0.4)))
	vendedor.vendio.connect(func(monto): _avisar_si_jugador(vendedor, tr("MSJ_VENTA") % monto, Color(0.6, 1.0, 0.5)))
	vendedor.no_quiso.connect(func(): _avisar_si_jugador(vendedor, tr("MSJ_NO_QUISO"), Color(1.0, 0.9, 0.7)))
	vendedor.se_le_cayeron.connect(func(cuantos): _avisar_si_jugador(vendedor, tr("MSJ_DULCES_CAIDOS") % cuantos, Color(1.0, 0.75, 0.3)))
	vendedor.reabastecio.connect(func(): _avisar_si_jugador(vendedor, tr("MSJ_REABASTECIO"), Color(0.7, 0.9, 1.0)))


func _avisar_si_jugador(nodo: Node, texto: String, color: Color) -> void:
	if nodo.get("cuerpo") == jugador:
		hud.mensaje(texto, color)


func _crear_jugador() -> CuerpoPersonaje:
	var cuerpo := BotInterior.nuevo_cuerpo("Jugador", MODELOS[rol])
	var camara := Camera3D.new()
	camara.name = "CamaraJugador"
	camara.fov = 80.0
	camara.near = 0.05
	interior.agregar(cuerpo, camara, Transform3D(Basis(), PUESTOS["voceador"] if rol == "voceador" else PUESTO_JUGADOR))
	cuerpo.orientar(PI)
	cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
	cuerpo.visual.ocultar_cabeza(true)
	ragdolls.vigilar(cuerpo)
	pasajeros.agregar_jugador(cuerpo)
	var entrada := EntradaJugador.new()
	entrada.name = "EntradaJugador"
	entrada.cuerpo = cuerpo
	add_child(entrada)
	return cuerpo


## Un bot que empieza la ruta a bordo con su rol (el vendedor no: sube él solo en algunas paradas).
func _crear_bot_a_bordo(r: String) -> void:
	if r == "vendedor":
		return
	var cuerpo := _cuerpo_de_bot(MODELOS[r])
	interior.agregar(cuerpo, null, Transform3D(Basis(), PUESTOS[r]))
	cuerpo.orientar(PI)
	_preparar_cuerpo_de_bot(cuerpo)
	_asignar(cuerpo, r)
	if r == "chofer":
		pasajeros.sentar_al_volante(cuerpo)


## Un bot nuevo que sube por la puerta desde la banqueta para cubrir un rol (en la rotación, si el
## rol que tomó el jugador no tenía a nadie a bordo).
func _bot_que_sube(r: String) -> void:
	var cuerpo := _cuerpo_de_bot(MODELOS[r])
	var afuera := camion.global_transform * (GestorPasajeros.PUERTA_AFUERA + Vector3(1.0, 0.0, 0.5))
	interior.agregar_en_calle(cuerpo, null, Transform3D(Basis(), afuera + Vector3.UP * 0.05))
	_preparar_cuerpo_de_bot(cuerpo)
	_asignar(cuerpo, r)
	_cerebros[cuerpo].subir_por_la_puerta()


func _cuerpo_de_bot(modelo: String) -> CuerpoPersonaje:
	_contador_bots += 1
	return BotInterior.nuevo_cuerpo("Bot%d_%s" % [_contador_bots, modelo], modelo)


func _preparar_cuerpo_de_bot(cuerpo: CuerpoPersonaje) -> void:
	cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
	cuerpo.atravesar_personajes(true)
	ragdolls.vigilar(cuerpo)


## Le da el rol `r` a este cuerpo: le quita lo que tenía (su nodo de rol, su cerebro de bot) y le
## pone lo nuevo. No lo mueve: si es bot, su cerebro lo lleva caminando a su puesto.
func _asignar(cuerpo: CuerpoPersonaje, r: String) -> void:
	for nodo in [cobrador, voceador, vendedor]:
		if nodo.cuerpo == cuerpo:
			nodo.cuerpo = null
	if _cerebros.has(cuerpo):
		_cerebros[cuerpo].queue_free()
		_cerebros.erase(cuerpo)
	if bot_vendedor.cuerpo == cuerpo:
		bot_vendedor.soltar_cuerpo()
	for otro_rol in _ocupantes.keys():
		if _ocupantes[otro_rol] == cuerpo:
			_ocupantes.erase(otro_rol)
	_ocupantes[r] = cuerpo
	match r:
		"cobrador":
			cobrador.cuerpo = cuerpo
		"voceador":
			voceador.cuerpo = cuerpo
		"vendedor":
			vendedor.cuerpo = cuerpo
	if cuerpo == jugador:
		rol = r
		chofer_es_jugador = r == "chofer"
		hud.configurar(r)
		# Si el vendedor ahora es el jugador, el bot vendedor no sube a nadie (y el que venía se va).
		bot_vendedor.activo = r != "vendedor" and (bots_activos == null or "vendedor" in bots_activos)
		if r == "vendedor" and bot_vendedor.cuerpo != null:
			bot_vendedor.despedir()
		if r != "chofer" and pasajeros.al_volante == cuerpo:
			pasajeros.dejar_volante(cuerpo)
	elif r == "vendedor":
		bot_vendedor.tomar_cuerpo(cuerpo)
	else:
		var cerebro := _cerebro_para(r)
		cerebro.name = "Bot_%s_%s" % [r, cuerpo.name]
		cerebro.cuerpo = cuerpo
		cerebro.pasajeros = pasajeros
		cerebro.puesto = PUESTOS[r]
		_cerebros[cuerpo] = cerebro
		add_child(cerebro)
	_actualizar_bots()


func _cerebro_para(r: String) -> BotInterior:
	match r:
		"chofer":
			return BotChofer.new()
		"cobrador":
			return BotCobrador.new()
		"voceador":
			var bot := BotVoceador.new()
			bot.voceador = voceador
			return bot
	return null


func _actualizar_bots() -> void:
	bots.clear()
	for cuerpo in _cerebros:
		for r in _ocupantes:
			if _ocupantes[r] == cuerpo:
				bots[r] = _cerebros[cuerpo]
	if rol != "vendedor" and bot_vendedor.activo:
		bots["vendedor"] = bot_vendedor


## Quien va al volante: el jugador maneja con su entrada; un bot, con el piloto automático.
## Nadie: el camión se queda con los pedales sueltos.
func _al_cambiar_volante(cuerpo: CuerpoPersonaje) -> void:
	for otro in [jugador] + _cerebros.keys():
		if otro != null and is_instance_valid(otro) and otro != cuerpo:
			otro.manejando = false
	if cuerpo != null:
		cuerpo.manejando = true
	# Solo el jugador al volante puede salir volando del asiento (el bot chofer no, D23).
	jugador.umbral_salir_del_asiento = _roles.umbral_salir_del_asiento if cuerpo == jugador else 0.0
	if cuerpo != null:
		piloto.sin_chofer = false
	if cuerpo == jugador:
		piloto.activo = false
		if _entrada_chofer == null or not is_instance_valid(_entrada_chofer):
			_entrada_chofer = EntradaChofer.new()
			_entrada_chofer.name = "EntradaChofer"
			_entrada_chofer.camion = camion
			add_child(_entrada_chofer)
		return
	if _entrada_chofer != null and is_instance_valid(_entrada_chofer):
		_entrada_chofer.queue_free()
	_entrada_chofer = null
	camion.comandos.limpiar()
	if cuerpo == null:
		piloto.activo = false
		return
	# Un bot toma el volante: si el camión está en una parada, espera lo que le queda a la ventana.
	var parada := pasajeros.parada_actual
	var queda := maxf(2.0, pasajeros.duracion_ventana() - pasajeros.tiempo_en_parada) if parada >= 0 else 0.0
	piloto.tomar_volante(parada, _ultima_parada, queda)
	piloto.activo = true
	if _arranque <= 0.0 and piloto.modo == PilotoAutomatico.Modo.PARADO:
		piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)


# --- Cada cuadro ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _arranque > 0.0:
		_arranque -= delta
		if _arranque <= 0.0 and piloto.activo:
			piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	var parada := pasajeros.parada_actual
	var llego_a_parada := parada >= 0 and parada != _parada_anterior
	_parada_anterior = parada
	if parada >= 0:
		_ultima_parada = parada
	if llego_a_parada:
		_paradas_vistas += 1
	# Los puestos rotan ya con el camión quieto: al llegar hay un último tirón del freno y quien
	# se suelta para ir a su puesto nuevo sale volando.
	if modo == "paro" and parada >= 0 and _paradas_vistas > 1 and not _es_terminal(parada) and parada != _rotada_en and pasajeros.tiempo_en_parada >= ESPERA_PARA_ROTAR:
		_rotada_en = parada
		_rotar()
	# Al volante solo va el chofer: si quedó alguien más (le acaban de cambiar el rol), se para.
	if pasajeros.al_volante != null and pasajeros.al_volante != ocupante("chofer"):
		pasajeros.dejar_volante(pasajeros.al_volante)
	if pasajeros.al_volante != null:
		pasajeros.al_volante.volante = camion.volante
	_atender_puerta()
	_revisar_volante_vacio()
	_rescatar_volante()
	_reaparecer(delta, llego_a_parada)
	_atender_chofer(delta, llego_a_parada)
	_revisar_fin(delta)
	_actualizar_hud()


## "Tírame paro": el jugador recibe otro rol al azar y quien lo tenía se queda con el suyo. Si el
## rol nuevo no tenía a nadie a bordo (el vendedor bot no venía), sube un bot nuevo a cubrir el
## que dejó el jugador. Todos caminan a su puesto.
func _rotar() -> void:
	var anterior := rol
	var opciones: Array = Juego.ROLES.filter(func(r): return r != anterior)
	var nuevo: String = opciones[_azar.randi() % opciones.size()]
	var otro := ocupante(nuevo)
	# El bot vendedor que todavía sube o ya se va no cuenta como a bordo.
	if nuevo == "vendedor" and not bot_vendedor.vendiendo():
		otro = null
	_rol_antes_de_rotar = anterior
	_asignar(jugador, nuevo)
	if otro != null:
		_asignar(otro, anterior)
	else:
		_bot_que_sube(anterior)
	rotaciones += 1
	hud.anunciar(tr("ANUNCIO_ROTACION") % tr("ROL_" + nuevo.to_upper()), Color(0.7, 1.0, 0.7))


## Si al jugador le tocó manejar y no se sienta antes de que se acabe la ventana (más un rato), el
## bot que tomó su rol regresa al volante y el jugador recupera el rol que tenía.
## En Modo normal el jugador se queda con su rol: un bot de a bordo maneja hasta la siguiente
## parada (sin penalización: el chofer va a bordo) y ahí le devuelve el volante.
func _revisar_volante_vacio() -> void:
	var parada := pasajeros.parada_actual
	if rol != "chofer" or pasajeros.al_volante != null or _sustituto != null or parada < 0 or parada == _volante_recuperado_en:
		return
	if pasajeros.tiempo_en_parada < pasajeros.duracion_ventana() + _roles.espera_sin_chofer:
		return
	_volante_recuperado_en = parada
	if modo != "paro":
		_poner_sustituto()
		return
	var de_vuelta := _rol_antes_de_rotar if _rol_antes_de_rotar != "" and _rol_antes_de_rotar != "chofer" else "cobrador"
	var bot := ocupante(de_vuelta)
	_asignar(jugador, de_vuelta)
	if bot != null:
		_asignar(bot, "chofer")
	else:
		_bot_que_sube("chofer")
	volantes_recuperados += 1
	hud.anunciar(tr("ANUNCIO_BOT_AL_VOLANTE") % tr("ROL_" + de_vuelta.to_upper()), Color(1.0, 0.75, 0.4))


## El chofer jugador fuera del volante con el camión andando (DISEÑO.md, 5.3): el camión sigue de
## inercia por su carril y se va frenando, la gente se desespera y, a los pocos segundos, un bot de
## a bordo deja su puesto y se sienta a manejar. En la primera parada a la que llega sin su chofer
## se cobra "el chofer no entregó el camión" (una vez). Ahí el bot vuelve a su puesto: en Modo
## normal el chofer retoma el volante; en "Tírame paro" entra a la rotación de esa parada (D21).
func _atender_chofer(delta: float, llego_a_parada: bool) -> void:
	var parada := pasajeros.parada_actual
	var sin_nadie := pasajeros.al_volante == null
	var andando := parada < 0 and absf(camion.velocidad_adelante) > 1.0
	pasajeros.sin_chofer = sin_nadie and andando
	if sin_nadie and parada < 0 and _arranque <= 0.0:
		# Sigue de inercia: el piloto solo lo mantiene en su carril.
		if not piloto.sin_chofer or not piloto.activo:
			piloto.tomar_volante(-1, _ultima_parada, 0.0)
			piloto.sin_chofer = true
			piloto.activo = true
			if piloto.modo == PilotoAutomatico.Modo.PARADO:
				piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	elif sin_nadie and piloto.sin_chofer:
		piloto.activo = false
		camion.comandos.limpiar()
	if rol == "chofer" and sin_nadie and andando and _sustituto == null and not _incidente:
		_incidente = true
		_sin_chofer = 0.0
		hud.anunciar(tr("ANUNCIO_SIN_CHOFER"), Color(1.0, 0.45, 0.35))
	if _incidente and pasajeros.al_volante == jugador:
		# Regresó al volante antes que el sustituto: entregó el camión.
		_incidente = false
	if _incidente and sin_nadie and _sustituto == null:
		_sin_chofer += delta
		if _sin_chofer >= _roles.segundos_hasta_sustituto:
			_poner_sustituto()
	if not llego_a_parada:
		return
	if _incidente:
		_incidente = false
		var cobrado := Juego.penalizar(Juego.parametros.penalizacion_chofer)
		penalizaciones_chofer += 1
		hud.mensaje(tr("MSJ_CHOFER_NO_ENTREGO") % cobrado, Color(1.0, 0.5, 0.4))
	if _sustituto != null:
		_devolver_volante()


## Un bot de a bordo (el cobrador o el voceador) deja su puesto y va a sentarse al volante.
func _poner_sustituto() -> void:
	var elegido: CuerpoPersonaje = null
	for r in ["cobrador", "voceador"]:
		var c := ocupante(r)
		if c != null and c != jugador and not c.desplomado and interior.esta_dentro(c):
			elegido = c
			_rol_del_sustituto = r
			break
	if elegido == null:
		# No hay nadie a bordo que pueda: aparece un chofer junto al volante (no debería pasar).
		push_warning("No había bot a bordo para tomar el volante: aparece uno junto a él.")
		elegido = _cuerpo_de_bot(MODELOS["chofer"])
		interior.agregar(elegido, null, Transform3D(Basis(), GestorPasajeros.JUNTO_AL_VOLANTE))
		_preparar_cuerpo_de_bot(elegido)
		_rol_del_sustituto = ""
	_sustituto = elegido
	_asignar(elegido, "chofer")
	sustituciones += 1
	hud.anunciar(tr("ANUNCIO_SUSTITUTO") % tr("ROL_" + (_rol_del_sustituto if _rol_del_sustituto != "" else "chofer").to_upper()), Color(1.0, 0.75, 0.4))


## El sustituto deja el volante y vuelve a su puesto; el rol de chofer regresa al jugador.
func _devolver_volante() -> void:
	var bot := _sustituto
	_sustituto = null
	_ocupantes.erase("chofer")
	if bot == null or not is_instance_valid(bot):
		return
	if _rol_del_sustituto != "":
		_asignar(bot, _rol_del_sustituto)
	else:
		# El que apareció de emergencia se baja.
		if _cerebros.has(bot):
			_cerebros[bot].queue_free()
			_cerebros.erase(bot)
		if pasajeros.al_volante == bot:
			pasajeros.dejar_volante(bot)
		interior.quitar(bot)
		bot.queue_free()
	_rol_del_sustituto = ""
	_actualizar_bots()


## Red de seguridad: si el camión lleva mucho en una parada sin nadie al volante y el chofer es un
## bot que no llega (atorado, tirado afuera), se le pone junto al volante para que se siente. Es
## lo único que mueve a alguien sin caminar, y solo pasa si algo salió mal.
func _rescatar_volante() -> void:
	var chofer := ocupante("chofer")
	if pasajeros.al_volante != null or pasajeros.parada_actual < 0 or chofer == null or chofer == jugador or chofer.desplomado:
		return
	if pasajeros.tiempo_en_parada < pasajeros.duracion_ventana() + _roles.espera_sin_chofer * 2.0:
		return
	interior.recolocar(chofer, Transform3D(Basis(), GestorPasajeros.JUNTO_AL_VOLANTE))
	if _cerebros.has(chofer):
		_cerebros[chofer].por_recorrer.clear()
	push_warning("El bot chofer no llegaba al volante (estaba en %s, parada %d, %.0f s): se le puso junto a él." % [interior.posicion_local(chofer).snapped(Vector3.ONE * 0.1), pasajeros.parada_actual, pasajeros.tiempo_en_parada])
	volantes_rescatados += 1


func _es_terminal(k: int) -> bool:
	return not calle.cerrada and k == calle.paradas.size() - 1


## El jugador chofer abre y cierra la puerta con su acción. El bot chofer la abre al llegar a la
## primera parada y la deja abierta.
func _atender_puerta() -> void:
	if pasajeros.al_volante == jugador:
		if camion.comandos.puerta:
			camion.comandos.puerta = false
			interior.fijar_puerta(not interior.puerta_abierta)
	elif pasajeros.al_volante != null and pasajeros.parada_actual >= 0 and not interior.puerta_abierta:
		interior.fijar_puerta(true)


## Si el jugador se queda abajo (salió volando o se bajó), reaparece en la siguiente parada
## pagando la penalización (en la etapa 4, si no alcanza, reaparece gratis).
func _reaparecer(delta: float, llego_a_parada: bool) -> void:
	if interior.esta_dentro(jugador) or jugador.desplomado:
		_fuera = 0.0
		_esperando_reaparecer = false
		return
	_fuera += delta
	if _fuera > TIEMPO_PARA_QUEDARSE_ABAJO:
		_esperando_reaparecer = true
	if _esperando_reaparecer and llego_a_parada:
		var pagada := Juego.pagar_reaparicion()
		interior.recolocar(jugador, Transform3D(Basis(), PUESTOS["voceador"] if rol == "voceador" else PUESTO_JUGADOR))
		jugador.orientar(PI)
		_esperando_reaparecer = false
		if pagada:
			hud.mensaje(tr("MSJ_REAPARECER") % Juego.parametros.penalizacion_reaparecer, Color(1.0, 0.6, 0.4))
		else:
			hud.mensaje(tr("MSJ_REAPARECER_GRATIS"), Color(1.0, 0.8, 0.4))


## Si el camión ya está en la terminal: detenido en la última parada.
func en_terminal() -> bool:
	if piloto.activo and piloto.en_terminal:
		return true
	return _es_terminal(pasajeros.parada_actual)


## En la terminal: cuando se bajó todo el mundo (o pasó la ventana), se cierra la ruta.
func _revisar_fin(delta: float) -> void:
	if terminada or not en_terminal():
		return
	_en_terminal += delta
	if pasajeros.a_bordo() == 0 or _en_terminal > Juego.parametros.ventana:
		terminar_ruta()


func terminar_ruta() -> void:
	if terminada:
		return
	terminada = true
	if cobrador.morral > 0:
		Juego.ingresar(cobrador.morral)
		cobrador.morral = 0
	var ganancia := Juego.dinero.ganancia_ruta
	var cuota := Juego.dinero.cuota
	var cumplida := Juego.cerrar_ruta()
	resultado = {
		"cumplida": cumplida, "ganancia": ganancia, "cuota": cuota, "fondo": Juego.dinero.fondo,
		"cobrados": pasajeros.total_subieron - pasajeros.total_sin_pagar, "sin_pagar": pasajeros.total_sin_pagar,
		"regado": cobrador.total_regado, "perdido": cobrador.total_perdido,
		"rutas_cumplidas": Juego.dinero.rutas_cumplidas, "total_ganado": Juego.dinero.total_ganado,
	}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var pantalla := ResultadoRuta.new()
	pantalla.name = "Resultado"
	add_child(pantalla)
	pantalla.mostrar(resultado)
	pantalla.siguiente_ruta.connect(func(): get_tree().change_scene_to_file.call_deferred(ESCENA_RUTA))
	pantalla.volver_al_menu.connect(func():
		Juego.en_partida = false
		get_tree().change_scene_to_file.call_deferred(ESCENA_MENU))


func _actualizar_hud() -> void:
	var d := Juego.dinero
	var al_volante := pasajeros.al_volante == jugador
	if al_volante:
		hud.mostrar_estado(camion.velocidad_adelante * 3.6, "", true, false, false)
	else:
		var modo_piloto: String = PilotoAutomatico.NOMBRES[piloto.modo] if piloto.activo else ""
		hud.mostrar_estado(camion.velocidad_adelante * 3.6, modo_piloto, interior.esta_dentro(jugador) or jugador.desplomado, jugador.sujetado, jugador.tropezando > 0.0 or jugador.desplomado)
	hud.mostrar_pasajeros(pasajeros.a_bordo())
	hud.mostrar_dinero(d.fondo, d.ganancia_ruta, d.cuota, cobrador.morral)
	var parada := pasajeros.parada_actual
	var siguiente := (parada if parada >= 0 else _ultima_parada + 1) + 1
	hud.mostrar_parada(siguiente, calle.paradas.size(), pasajeros.duracion_ventana() - pasajeros.tiempo_en_parada, parada >= 0)
	var nombre := tr("ROL_" + rol.to_upper())
	match rol:
		"chofer":
			if not al_volante:
				hud.mostrar_rol(nombre + " · " + tr("HUD_IR_AL_VOLANTE"), Color(1.0, 0.75, 0.4))
			else:
				hud.mostrar_rol(nombre + " · " + (tr("HUD_PUERTA_ABIERTA") if interior.puerta_abierta else tr("HUD_PUERTA_CERRADA")), Color(0.7, 1.0, 0.7) if interior.puerta_abierta else Color(1.0, 0.75, 0.4))
		"voceador":
			var texto := nombre + " · " + tr("HUD_ALIENTO") % roundi(voceador.aliento)
			if jugador.colgado:
				texto += " · " + tr("HUD_COLGADO")
			if voceador.gritando:
				texto += " · " + tr("HUD_GRITANDO")
			hud.mostrar_rol(texto, Color(1.0, 0.9, 0.6) if voceador.aliento > 25.0 else Color(1.0, 0.5, 0.4))
		"vendedor":
			hud.mostrar_rol(nombre + " · " + tr("HUD_DULCES") % [vendedor.mercancia, _roles.mercancia], Color(1.0, 0.9, 0.6) if vendedor.mercancia > 0 else Color(1.0, 0.5, 0.4))
		_:
			hud.mostrar_rol(nombre)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("salir_al_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Juego.en_partida = false
		get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)
	elif terminada:
		return
	elif not piloto.activo:
		pass
	elif evento.is_action_pressed("piloto_parado"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	elif evento.is_action_pressed("piloto_tranquilo"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.TRANQUILO)
	elif evento.is_action_pressed("piloto_normal"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	elif evento.is_action_pressed("piloto_loco"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	if evento is InputEventMouseButton and evento.pressed and not terminada:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
