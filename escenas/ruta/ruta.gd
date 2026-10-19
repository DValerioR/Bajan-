extends Node3D
## Una ruta completa (etapas 4 a 6A): GeneradorRuta arma la calle por zonas y en el camino pasan
## los eventos de PlanEventos (GestorEventos). El jugador tiene el rol que eligió (Juego.rol_jugador:
## chofer, cobrador, voceador o vendedor) y los demás puestos los cubren bots (DISEÑO.md, 5.1 y
## 5.2): el chofer automático (sentado al volante, D23) y los bots del interior.
## La puerta es física: el chofer la abre en las paradas para que suban y bajen; el bot chofer la
## deja abierta al arrancar, como los micros de verdad.
## Al llegar a la terminal se cierra la ruta contra la cuota y se muestra el resultado.
## El estado de la partida (dinero, número de ruta, rol) vive en el autoload Juego.

const ESCENA_MENU := "res://escenas/principal.tscn"
const ESCENA_RUTA := "res://escenas/ruta/ruta.tscn"
## Dónde aparece el jugador: junto a la puerta, mirando hacia el fondo (coordenadas del camión).
const PUESTO_JUGADOR := Vector3(0.35, -0.28, -3.0)
## Puestos de los del interior (coordenadas del camión): el voceador en la puerta, junto al poste.
const PUESTO_VOCEADOR := Vector3(1.05, -0.28, -2.8)
const PUESTO_COBRADOR := Vector3(0.0, -0.28, 0.0)
const PUESTO_VENDEDOR := Vector3(-0.3, -0.28, 1.0)
## Modelo de personaje de cada rol.
const MODELOS := {"chofer": "chofer", "cobrador": "cobrador", "voceador": "voceador", "vendedor": "vendedora"}
## Roles del interior (los que camina un personaje).
const ROLES_INTERIOR := ["cobrador", "voceador", "vendedor"]
## Segundos fuera del camión (de pie) antes de considerar que se quedó abajo.
const TIEMPO_PARA_QUEDARSE_ABAJO := 1.0

## Para las pruebas: semilla fija de la partida (-1 = al azar).
static var semilla_forzada: int = -1
## Para las pruebas: qué eventos pueden pasar (null = lo que diga config/eventos.cfg).
static var eventos_activos: Variant = null
## Para las pruebas: qué roles del interior cubren bots (null = todos los que no tiene el jugador).
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
var chofer: ChoferSentado
var rol: String = "cobrador"
## Si el jugador maneja (entonces no tiene cuerpo que camine).
var chofer_es_jugador: bool = false
## El cuerpo del jugador (null si es el chofer).
var jugador: CuerpoPersonaje
## Los nodos de cada rol, de quien lo tenga (jugador o bot); null si nadie lo cubre.
var cobrador: Cobrador
var voceador: Voceador
## El vendedor del jugador (el del bot vive dentro de BotVendedor, solo cuando va a bordo).
var vendedor: Vendedor
## Bots del interior por rol.
var bots: Dictionary = {}
## Puestos de dulces (coordenadas del mundo).
var puestos: Array[Vector3] = []
var terminada: bool = false
var resultado: Dictionary = {}

var _roles: ParametrosRoles
var _arranque: float = 1.5
var _fuera: float = 0.0
var _esperando_reaparecer: bool = false
var _parada_anterior: int = -1
var _en_terminal: float = 0.0
## Última parada en la que se detuvo el camión (maneje quien maneje).
var _ultima_parada: int = -1


func _ready() -> void:
	if not Juego.en_partida:
		Juego.nueva_partida(semilla_forzada)
	rol = Juego.rol_jugador
	chofer_es_jugador = rol == "chofer"
	_roles = ParametrosRoles.cargar()
	var semilla := Juego.siguiente_ruta()
	descripcion = GeneradorRuta.generar(semilla, Juego.dinero.numero_ruta)
	# Si maneja el jugador, "el chofer trae prisa" no tiene sentido.
	var plan := PlanEventos.generar(descripcion, semilla, eventos_activos, ["prisa"] if chofer_es_jugador else [])
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
	add_child(pasajeros)
	piloto = PilotoAutomatico.new()
	piloto.name = "PilotoAutomatico"
	piloto.camion = camion
	piloto.pista = calle
	piloto.espera_fija = Juego.parametros.ventana
	piloto.activo = not chofer_es_jugador
	add_child(piloto)
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	piloto.susto.connect(hud.avisar_susto)
	chofer = ChoferSentado.sentar_en(camion)

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

	if chofer_es_jugador:
		_tomar_el_volante()
	else:
		jugador = _crear_jugador()
	for rol_bot in ROLES_INTERIOR:
		if rol_bot != rol and (bots_activos == null or rol_bot in bots_activos):
			_crear_bot(rol_bot)
	hud.configurar(rol)
	pasajeros.bajo_sin_pagar.connect(func(_c, monto): hud.mensaje(tr("MSJ_SIN_PAGAR") % monto, Color(1.0, 0.5, 0.4)))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## El jugador maneja: va sentado al volante (como el bot, no sale volando en la 6A), con la
## cámara del chofer, y el piloto automático no toca el camión.
func _tomar_el_volante() -> void:
	chofer.figura.ocultar_cabeza(true)
	var camara: Camera3D = camion.get_node("Carroceria/CamaraChofer")
	camara.make_current()
	var entrada := EntradaChofer.new()
	entrada.name = "EntradaChofer"
	entrada.camion = camion
	add_child(entrada)


func _crear_jugador() -> CuerpoPersonaje:
	var cuerpo := BotInterior.nuevo_cuerpo("Jugador", MODELOS[rol])
	var camara := Camera3D.new()
	camara.name = "CamaraJugador"
	camara.fov = 80.0
	camara.near = 0.05
	var puesto := PUESTO_VOCEADOR if rol == "voceador" else PUESTO_JUGADOR
	interior.agregar(cuerpo, camara, Transform3D(Basis(), puesto))
	cuerpo.orientar(PI)
	cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
	cuerpo.visual.ocultar_cabeza(true)
	ragdolls.vigilar(cuerpo)
	pasajeros.agregar_jugador(cuerpo)
	var entrada := EntradaJugador.new()
	entrada.name = "EntradaJugador"
	entrada.cuerpo = cuerpo
	add_child(entrada)
	match rol:
		"cobrador":
			cobrador = _nuevo_cobrador(cuerpo)
			cobrador.cobro.connect(func(monto): hud.mensaje(tr("MSJ_COBRO") % monto, Color(0.6, 1.0, 0.5)))
			cobrador.se_rego.connect(func(monto): hud.mensaje(tr("MSJ_REGO") % monto, Color(1.0, 0.75, 0.3)))
			cobrador.entrego.connect(func(monto): hud.mensaje(tr("MSJ_ENTREGA") % monto, Color(0.7, 0.9, 1.0)))
			cobrador.moneda_perdida.connect(func(monto): hud.mensaje(tr("MSJ_MONEDA_PERDIDA") % monto, Color(1.0, 0.5, 0.4)))
		"voceador":
			voceador = _nuevo_voceador(cuerpo)
			voceador.ayudo.connect(func(): hud.mensaje(tr("MSJ_AYUDO"), Color(0.7, 0.9, 1.0)))
		"vendedor":
			vendedor = Vendedor.new()
			vendedor.name = "Vendedor"
			vendedor.cuerpo = cuerpo
			vendedor.pasajeros = pasajeros
			vendedor.ragdolls = ragdolls
			vendedor.puestos = puestos
			add_child(vendedor)
			vendedor.vendio.connect(func(monto): hud.mensaje(tr("MSJ_VENTA") % monto, Color(0.6, 1.0, 0.5)))
			vendedor.no_quiso.connect(func(): hud.mensaje(tr("MSJ_NO_QUISO"), Color(1.0, 0.9, 0.7)))
			vendedor.se_le_cayeron.connect(func(cuantos): hud.mensaje(tr("MSJ_DULCES_CAIDOS") % cuantos, Color(1.0, 0.75, 0.3)))
			vendedor.reabastecio.connect(func(): hud.mensaje(tr("MSJ_REABASTECIO"), Color(0.7, 0.9, 1.0)))
	return cuerpo


func _crear_bot(rol_bot: String) -> void:
	var bot: BotInterior
	match rol_bot:
		"cobrador":
			bot = BotCobrador.new()
			bot.puesto = PUESTO_COBRADOR
		"voceador":
			bot = BotVoceador.new()
			bot.puesto = PUESTO_VOCEADOR
		"vendedor":
			var bot_vendedor := BotVendedor.new()
			bot_vendedor.ragdolls = ragdolls
			bot_vendedor.modelo = MODELOS["vendedor"]
			bot = bot_vendedor
			bot.puesto = PUESTO_VENDEDOR
	bot.name = "Bot_" + rol_bot
	bot.pasajeros = pasajeros
	# El vendedor sube y baja en algunas paradas: su cuerpo lo crea él mismo.
	if rol_bot != "vendedor":
		var cuerpo := BotInterior.nuevo_cuerpo("Bot" + rol_bot.capitalize(), MODELOS[rol_bot])
		interior.agregar(cuerpo, null, Transform3D(Basis(), bot.puesto))
		cuerpo.orientar(PI)
		cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
		cuerpo.atravesar_personajes(true)
		ragdolls.vigilar(cuerpo)
		bot.cuerpo = cuerpo
		if rol_bot == "cobrador":
			cobrador = _nuevo_cobrador(cuerpo)
		else:
			voceador = _nuevo_voceador(cuerpo)
			(bot as BotVoceador).voceador = voceador
	bots[rol_bot] = bot
	add_child(bot)


func _nuevo_cobrador(cuerpo: CuerpoPersonaje) -> Cobrador:
	var nodo := Cobrador.new()
	nodo.name = "Cobrador"
	nodo.cuerpo = cuerpo
	nodo.pasajeros = pasajeros
	nodo.ragdolls = ragdolls
	add_child(nodo)
	return nodo


func _nuevo_voceador(cuerpo: CuerpoPersonaje) -> Voceador:
	var nodo := Voceador.new()
	nodo.name = "Voceador"
	nodo.cuerpo = cuerpo
	nodo.pasajeros = pasajeros
	add_child(nodo)
	return nodo


func _physics_process(delta: float) -> void:
	if _arranque > 0.0:
		_arranque -= delta
		if _arranque <= 0.0 and not chofer_es_jugador:
			piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	if pasajeros.parada_actual >= 0:
		_ultima_parada = pasajeros.parada_actual
	_atender_puerta()
	_reaparecer(delta)
	_revisar_fin(delta)
	_actualizar_hud()


## El jugador chofer abre y cierra la puerta con su acción. El bot chofer la abre al llegar a la
## primera parada y la deja abierta.
func _atender_puerta() -> void:
	if chofer_es_jugador:
		if camion.comandos.puerta:
			camion.comandos.puerta = false
			interior.fijar_puerta(not interior.puerta_abierta)
	elif pasajeros.parada_actual >= 0 and not interior.puerta_abierta:
		interior.fijar_puerta(true)


## Si el jugador se queda abajo (salió volando o se bajó), reaparece en la siguiente parada
## pagando la penalización (en la etapa 4, si no alcanza, reaparece gratis).
func _reaparecer(delta: float) -> void:
	var parada := pasajeros.parada_actual
	var llego_a_parada := parada >= 0 and parada != _parada_anterior
	_parada_anterior = parada
	if jugador == null or interior.esta_dentro(jugador) or jugador.desplomado:
		_fuera = 0.0
		_esperando_reaparecer = false
		return
	_fuera += delta
	if _fuera > TIEMPO_PARA_QUEDARSE_ABAJO:
		_esperando_reaparecer = true
	if _esperando_reaparecer and llego_a_parada:
		var pagada := Juego.pagar_reaparicion()
		interior.recolocar(jugador, Transform3D(Basis(), PUESTO_VOCEADOR if rol == "voceador" else PUESTO_JUGADOR))
		jugador.orientar(PI)
		_esperando_reaparecer = false
		if pagada:
			hud.mensaje(tr("MSJ_REAPARECER") % Juego.parametros.penalizacion_reaparecer, Color(1.0, 0.6, 0.4))
		else:
			hud.mensaje(tr("MSJ_REAPARECER_GRATIS"), Color(1.0, 0.8, 0.4))


## Si el camión ya está en la terminal: el bot chofer lo sabe; si maneja el jugador, es cuando
## se detiene en la última parada.
func en_terminal() -> bool:
	if not chofer_es_jugador:
		return piloto.en_terminal
	return not calle.cerrada and pasajeros.parada_actual == calle.paradas.size() - 1


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
	if cobrador != null and cobrador.morral > 0:
		Juego.ingresar(cobrador.morral)
		cobrador.morral = 0
	var ganancia := Juego.dinero.ganancia_ruta
	var cuota := Juego.dinero.cuota
	var cumplida := Juego.cerrar_ruta()
	resultado = {
		"cumplida": cumplida, "ganancia": ganancia, "cuota": cuota, "fondo": Juego.dinero.fondo,
		"cobrados": pasajeros.total_subieron - pasajeros.total_sin_pagar, "sin_pagar": pasajeros.total_sin_pagar,
		"regado": cobrador.total_regado if cobrador != null else 0, "perdido": cobrador.total_perdido if cobrador != null else 0,
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
	if jugador != null:
		hud.mostrar_estado(camion.velocidad_adelante * 3.6, PilotoAutomatico.NOMBRES[piloto.modo], interior.esta_dentro(jugador) or jugador.desplomado, jugador.sujetado, jugador.tropezando > 0.0 or jugador.desplomado)
	else:
		hud.mostrar_estado(camion.velocidad_adelante * 3.6, "", true, false, false)
	hud.mostrar_pasajeros(pasajeros.a_bordo())
	hud.mostrar_dinero(d.fondo, d.ganancia_ruta, d.cuota, cobrador.morral if cobrador != null else 0)
	var parada := pasajeros.parada_actual
	var siguiente := (parada if parada >= 0 else _ultima_parada + 1) + 1
	hud.mostrar_parada(siguiente, calle.paradas.size(), Juego.parametros.ventana - pasajeros.tiempo_en_parada, parada >= 0)
	match rol:
		"chofer":
			hud.mostrar_rol(tr("HUD_PUERTA_ABIERTA") if interior.puerta_abierta else tr("HUD_PUERTA_CERRADA"), Color(0.7, 1.0, 0.7) if interior.puerta_abierta else Color(1.0, 0.75, 0.4))
		"voceador":
			var texto := tr("HUD_ALIENTO") % roundi(voceador.aliento)
			if voceador.gritando:
				texto += " · " + tr("HUD_GRITANDO")
			hud.mostrar_rol(texto, Color(1.0, 0.9, 0.6) if voceador.aliento > 25.0 else Color(1.0, 0.5, 0.4))
		"vendedor":
			hud.mostrar_rol(tr("HUD_DULCES") % [vendedor.mercancia, _roles.mercancia], Color(1.0, 0.9, 0.6) if vendedor.mercancia > 0 else Color(1.0, 0.5, 0.4))
		_:
			hud.mostrar_rol("")


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("salir_al_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Juego.en_partida = false
		get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)
	elif terminada:
		return
	elif chofer_es_jugador:
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
