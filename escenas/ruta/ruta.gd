extends Node3D
## Una ruta completa (etapas 4 y 5): GeneradorRuta arma la calle por zonas, el chofer automático
## (sentado al volante, D23) maneja y se detiene en cada parada durante la ventana de parada, y el
## jugador es el cobrador (D39). En el camino pasan los eventos de PlanEventos (GestorEventos).
## Al llegar a la terminal se cierra la ruta contra la cuota y se muestra el resultado.
## El estado de la partida (dinero, número de ruta) vive en el autoload Juego.

const ESCENA_MENU := "res://escenas/principal.tscn"
const ESCENA_RUTA := "res://escenas/ruta/ruta.tscn"
## Dónde aparece el jugador: junto a la puerta, mirando hacia el fondo (coordenadas del camión).
const PUESTO_JUGADOR := Vector3(0.35, -0.28, -3.0)
## Segundos fuera del camión (de pie) antes de considerar que se quedó abajo.
const TIEMPO_PARA_QUEDARSE_ABAJO := 1.0

## Para las pruebas: semilla fija de la partida (-1 = al azar).
static var semilla_forzada: int = -1
## Para las pruebas: qué eventos pueden pasar (null = lo que diga config/eventos.cfg).
static var eventos_activos: Variant = null

@onready var camion: Camion = $Camion
@onready var mundo: Node3D = $Mundo
@onready var hud: HudInterior = $Hud

var descripcion: Dictionary
var calle: Calle
var interior: InteriorCamion
var ragdolls: GestorRagdolls
var pasajeros: GestorPasajeros
var piloto: PilotoAutomatico
var jugador: CuerpoPersonaje
var cobrador: Cobrador
var eventos: GestorEventos
var chofer: ChoferSentado
var terminada: bool = false
var resultado: Dictionary = {}

var _arranque: float = 1.5
var _fuera: float = 0.0
var _esperando_reaparecer: bool = false
var _parada_anterior: int = -1
var _en_terminal: float = 0.0


func _ready() -> void:
	if not Juego.en_partida:
		Juego.nueva_partida(semilla_forzada)
	var semilla := Juego.siguiente_ruta()
	descripcion = GeneradorRuta.generar(semilla, Juego.dinero.numero_ruta)
	var plan := PlanEventos.generar(descripcion, semilla, eventos_activos)
	PlanEventos.aplicar_a_descripcion(descripcion, plan)

	calle = Calle.new()
	calle.name = "Calle"
	calle.descripcion = descripcion
	add_child(calle)
	move_child(calle, 1)
	camion.colocar(calle.transform_en_indice(calle.indice_en_distancia(4.0)))

	interior = InteriorCamion.new()
	interior.name = "Interior"
	interior.camion = camion
	interior.mundo = mundo
	add_child(interior)
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

	jugador = _crear_jugador()
	pasajeros.agregar_jugador(jugador)
	cobrador = Cobrador.new()
	cobrador.name = "Cobrador"
	cobrador.cuerpo = jugador
	cobrador.pasajeros = pasajeros
	cobrador.ragdolls = ragdolls
	add_child(cobrador)
	cobrador.cobro.connect(func(monto): hud.mensaje(tr("MSJ_COBRO") % monto, Color(0.6, 1.0, 0.5)))
	cobrador.se_rego.connect(func(monto): hud.mensaje(tr("MSJ_REGO") % monto, Color(1.0, 0.75, 0.3)))
	cobrador.entrego.connect(func(monto): hud.mensaje(tr("MSJ_ENTREGA") % monto, Color(0.7, 0.9, 1.0)))
	cobrador.moneda_perdida.connect(func(monto): hud.mensaje(tr("MSJ_MONEDA_PERDIDA") % monto, Color(1.0, 0.5, 0.4)))
	pasajeros.bajo_sin_pagar.connect(func(_c, monto): hud.mensaje(tr("MSJ_SIN_PAGAR") % monto, Color(1.0, 0.5, 0.4)))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _crear_jugador() -> CuerpoPersonaje:
	var cuerpo := CuerpoPersonaje.new()
	cuerpo.name = "Jugador"
	cuerpo.parametros = ParametrosInterior.cargar()
	var visual := Personaje.new()
	visual.name = "Visual"
	visual.modelo = "cobrador"
	cuerpo.add_child(visual)
	cuerpo.visual = visual
	var camara := Camera3D.new()
	camara.name = "CamaraJugador"
	camara.fov = 80.0
	camara.near = 0.05
	interior.agregar(cuerpo, camara, Transform3D(Basis(), PUESTO_JUGADOR))
	cuerpo.orientar(PI)
	cuerpo.configurar(visual.altura, visual.altura_ojos)
	visual.ocultar_cabeza(true)
	ragdolls.vigilar(cuerpo)
	var entrada := EntradaJugador.new()
	entrada.name = "EntradaJugador"
	entrada.cuerpo = cuerpo
	add_child(entrada)
	return cuerpo


func _physics_process(delta: float) -> void:
	if _arranque > 0.0:
		_arranque -= delta
		if _arranque <= 0.0:
			piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	_reaparecer(delta)
	_revisar_fin(delta)
	_actualizar_hud()


## Si el jugador se queda abajo (salió volando o se bajó), reaparece en la siguiente parada
## pagando la penalización (en la etapa 4, si no alcanza, reaparece gratis).
func _reaparecer(delta: float) -> void:
	var parada := pasajeros.parada_actual
	var llego_a_parada := parada >= 0 and parada != _parada_anterior
	_parada_anterior = parada
	if interior.esta_dentro(jugador) or jugador.desplomado:
		_fuera = 0.0
		_esperando_reaparecer = false
		return
	_fuera += delta
	if _fuera > TIEMPO_PARA_QUEDARSE_ABAJO:
		_esperando_reaparecer = true
	if _esperando_reaparecer and llego_a_parada:
		var pagada := Juego.pagar_reaparicion()
		interior.recolocar(jugador, Transform3D(Basis(), PUESTO_JUGADOR))
		jugador.orientar(PI)
		_esperando_reaparecer = false
		if pagada:
			hud.mensaje(tr("MSJ_REAPARECER") % Juego.parametros.penalizacion_reaparecer, Color(1.0, 0.6, 0.4))
		else:
			hud.mensaje(tr("MSJ_REAPARECER_GRATIS"), Color(1.0, 0.8, 0.4))


## En la terminal: cuando se bajó todo el mundo (o pasó la ventana), se cierra la ruta.
func _revisar_fin(delta: float) -> void:
	if terminada or not piloto.en_terminal:
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
	hud.mostrar_estado(camion.velocidad_adelante * 3.6, PilotoAutomatico.NOMBRES[piloto.modo], interior.esta_dentro(jugador) or jugador.desplomado, jugador.sujetado, jugador.tropezando > 0.0 or jugador.desplomado)
	hud.mostrar_pasajeros(pasajeros.a_bordo())
	hud.mostrar_dinero(d.fondo, d.ganancia_ruta, d.cuota, cobrador.morral)
	var parada := pasajeros.parada_actual
	var siguiente := (parada if parada >= 0 else piloto.siguiente_parada()) + 1
	hud.mostrar_parada(siguiente, calle.paradas.size(), Juego.parametros.ventana - pasajeros.tiempo_en_parada, parada >= 0)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("salir_al_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Juego.en_partida = false
		get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)
	elif terminada:
		return
	elif evento.is_action_pressed("piloto_parado"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	elif evento.is_action_pressed("piloto_tranquilo"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.TRANQUILO)
	elif evento.is_action_pressed("piloto_normal"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	elif evento.is_action_pressed("piloto_loco"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	elif evento is InputEventMouseButton and evento.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
