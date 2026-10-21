extends Node
## Prueba automática de la etapa 6A: los cuatro roles y los bots del interior.
## Criterio: puedo elegir cualquier rol, los bots cubren los demás y se completa una ruta entera.
## - Con cada rol se corre una ruta completa. El jugador hace lo mínimo de su rol (o nada) y los
##   bots cubren el resto: el bot cobrador cobra, el bot voceador grita y jala gente, el bot
##   vendedor sube en algunas paradas y vende, y el bot chofer maneja.
## - El voceador (jugador o bot) se cuelga de la puerta y jala a la gente que hace la parada a medio
##   camino, con el camión en marcha (D55).
## - La puerta es física: cerrada, nadie sube ni sale volando por ahí.
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa6a.tscn [-- detalle]

const ESCENA := "res://escenas/ruta/ruta.tscn"
const Ruta := preload("res://escenas/ruta/ruta.gd")
const FPS := 60
const SEMILLA := 3

## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 30
var _fallos: int = 0
var _verificaciones: int = 0
var _detalle := false


func _ready() -> void:
	_detalle = OS.get_cmdline_user_args().has("detalle")
	await _probar_rol("cobrador")
	await _probar_rol("voceador")
	await _probar_rol("vendedor")
	await _probar_rol("chofer")
	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 6A: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 6A: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


func _probar_rol(rol: String) -> void:
	print("Ruta completa con el jugador de %s:" % rol)
	Juego.en_partida = false
	Juego.nueva_partida(SEMILLA, rol)
	Ruta.semilla_forzada = SEMILLA
	# Sin eventos: la prueba es de los roles (los eventos los prueba la etapa 5).
	Ruta.eventos_activos = []
	Ruta.bots_activos = null
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	for nombre in ["EntradaJugador", "EntradaChofer"]:
		if escena.has_node(nombre):
			escena.get_node(nombre).queue_free()
	escena.piloto.fijar_semilla(SEMILLA)
	escena.pasajeros.fijar_semilla(SEMILLA)
	for bot in escena.bots.values():
		bot.azar.seed = SEMILLA
	var pasajeros: GestorPasajeros = escena.pasajeros
	var interior: InteriorCamion = escena.interior
	var bots_esperados := Juego.ROLES.filter(func(r): return r != rol)
	_verificar(escena.bots.size() == bots_esperados.size() and bots_esperados.all(func(r): return escena.bots.has(r)), "los bots cubren los demás puestos: %s" % ", ".join(escena.bots.keys()))
	_verificar(not interior.puerta_abierta, "la ruta empieza con la puerta cerrada")

	var jugador: CuerpoPersonaje = escena.jugador
	var tiempo := 0.0
	var puerta_cerrada_en_parada := 0.0
	var subieron_con_puerta_cerrada := -1
	var reabastecio := false
	var dulces_antes := 0
	var regreso := false
	# Velocidad más baja del camión al jalar a alguien a medio camino (tiene que ir en marcha).
	var recogidas_en := [INF]
	escena.voceador.recogio.connect(func(_bono): recogidas_en[0] = minf(recogidas_en[0], absf(escena.camion.velocidad_adelante)))
	var para_colgarse := 0
	while not escena.terminada and tiempo < 1000.0:
		match rol:
			"chofer":
				# Hace de chofer el piloto automático, pero la puerta la abre "el jugador": en la
				# primera parada la deja cerrada un rato para ver que nadie sube.
				escena.piloto.activo = true
				if escena._arranque <= 0.0 and escena.piloto.modo == PilotoAutomatico.Modo.PARADO and tiempo > 1.6:
					escena.piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
				if pasajeros.parada_actual >= 0 and not interior.puerta_abierta:
					puerta_cerrada_en_parada += 1.0 / FPS
					if puerta_cerrada_en_parada > 3.0:
						subieron_con_puerta_cerrada = pasajeros.total_subieron
						escena.camion.comandos.puerta = true
			"voceador":
				jugador.comandos.sujetarse = true
				jugador.comandos.gritar = pasajeros.parada_que_oye() >= 0
				if pasajeros.parada_actual >= 0 and Engine.get_physics_frames() % 50 == 0:
					jugador.comandos.accion_rol = true
				# Entre paradas: se cuelga si alguien hace la parada adelante y lo jala al pasar.
				var orilla := pasajeros.orilla_adelante()
				var quiere := pasajeros.parada_actual < 0 and orilla < 70.0
				para_colgarse -= 1
				if quiere != jugador.colgado and (jugador.colgado or escena.voceador.puede_colgarse()) and para_colgarse <= 0:
					jugador.comandos.sentarse = true
					para_colgarse = 30
				if jugador.colgado and absf(orilla + Voceador.MANO_AFUERA.z) < 0.6:
					jugador.comandos.accion_rol = true
			"vendedor":
				jugador.comandos.sujetarse = true
				_vender_cerca(escena, jugador)
				# En la primera parada con puesto: se baja a llenar la caja y vuelve a subir.
				if not reabastecio and pasajeros.parada_actual >= 0 and escena.vendedor.mercancia < ParametrosRoles.cargar().mercancia:
					reabastecio = await _ir_al_puesto(escena, jugador)
					if reabastecio:
						dulces_antes = escena.vendedor.mercancia
						interior.recolocar(jugador, Transform3D(Basis(), Ruta.PUESTO_JUGADOR))
						regreso = true
			"cobrador":
				jugador.comandos.sujetarse = true
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
		if _detalle and Engine.get_physics_frames() % (20 * FPS) == 0:
			print("        [%.0f s] parada %d | a bordo %d | subieron %d | atraídos %d | ayudados %d | fondo $%d" % [tiempo, pasajeros.parada_actual, pasajeros.a_bordo(), pasajeros.total_subieron, pasajeros.total_atraidos, pasajeros.total_ayudados, Juego.dinero.fondo])

	_verificar(escena.terminada, "la ruta llega a la terminal y se cierra (%.0f s, %d paradas)" % [tiempo, escena.calle.paradas.size()])
	_verificar(pasajeros.total_subieron > 5, "suben pasajeros en el camino (%d)" % pasajeros.total_subieron)
	var bot_cobrador: Cobrador = escena.cobrador
	match rol:
		"cobrador":
			_verificar(escena.voceador.segundos_gritados > 3.0 and pasajeros.total_atraidos > 0, "el bot voceador grita (%.0f s) y junta gente (%d)" % [escena.voceador.segundos_gritados, pasajeros.total_atraidos])
			_verificar(escena.voceador.total_ayudados > 0, "el bot voceador jala a la gente que sube (%d)" % escena.voceador.total_ayudados)
			_verificar(escena.voceador.total_recogidos > 0 and recogidas_en[0] > 3.0, "el bot voceador jala a %d de %d a medio camino en marcha (%d se le resbalaron)" % [escena.voceador.total_recogidos, pasajeros.total_en_la_orilla, escena.voceador.total_resbalados])
			var bot_vendedor: BotVendedor = escena.bots["vendedor"]
			_verificar(bot_vendedor.veces_subio > 0 and bot_vendedor.total_ventas > 0, "el bot vendedor sube %d veces y vende %d dulces ($%d)" % [bot_vendedor.veces_subio, bot_vendedor.total_ventas, bot_vendedor.total_propinas])
		"voceador":
			_verificar(pasajeros.total_atraidos > 0, "el grito del jugador junta gente en las paradas (%d)" % pasajeros.total_atraidos)
			_verificar(escena.voceador.total_ayudados > 0, "el jugador jala a la gente que sube (%d)" % escena.voceador.total_ayudados)
			_verificar(escena.voceador.aliento <= 100.0 and escena.voceador.segundos_gritados > 0.0, "gritar gasta aliento y se recupera (%.0f s gritados)" % escena.voceador.segundos_gritados)
			_verificar(escena.voceador.total_recogidos > 0 and escena.voceador.total_bonos > 0 and recogidas_en[0] > 3.0, "colgado de la puerta jala a %d de %d a medio camino en marcha (a %.0f km/h o más, $%d de bono)" % [escena.voceador.total_recogidos, pasajeros.total_en_la_orilla, recogidas_en[0] * 3.6, escena.voceador.total_bonos])
			_verificar(bot_cobrador.total_cobrado > 0, "el bot cobrador cobra ($%d)" % bot_cobrador.total_cobrado)
		"vendedor":
			_verificar(escena.vendedor.total_ventas > 0 and escena.vendedor.total_propinas > 0, "el jugador vende %d dulces ($%d de propina)" % [escena.vendedor.total_ventas, escena.vendedor.total_propinas])
			_verificar(reabastecio and regreso and dulces_antes == ParametrosRoles.cargar().mercancia, "se baja al puesto de dulces y llena la caja")
			_verificar(bot_cobrador.total_cobrado > 0, "el bot cobrador cobra ($%d)" % bot_cobrador.total_cobrado)
		"chofer":
			_verificar(escena.chofer_es_jugador and pasajeros.al_volante == escena.jugador and escena.get_viewport().get_camera_3d().name == "CamaraJugador", "el jugador va sentado al volante, viendo desde su cabeza")
			_verificar(subieron_con_puerta_cerrada == 0, "con la puerta cerrada nadie sube (%d)" % subieron_con_puerta_cerrada)
			_verificar(bot_cobrador.total_cobrado > 0, "el bot cobrador cobra ($%d)" % bot_cobrador.total_cobrado)
			_verificar(pasajeros.total_atraidos > 0, "el bot voceador junta gente (%d)" % pasajeros.total_atraidos)
	escena.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if rol == "chofer":
		await _probar_puerta_cerrada()


## Ofrece dulce al pasajero sin ofrecer más cercano: se acerca a él (como lo haría el jugador).
func _vender_cerca(escena: Node, jugador: CuerpoPersonaje) -> void:
	if Engine.get_physics_frames() % 40 != 0 or not escena.interior.esta_dentro(jugador) or jugador.desplomado:
		return
	var pendientes: Array[CuerpoPersonaje] = escena.pasajeros.a_bordo_que("sin_ofrecer")
	if pendientes.is_empty():
		return
	var otro: CuerpoPersonaje = pendientes[0]
	var punto: Vector3 = escena.pasajeros.punto_para_atender(otro)
	var objetivo: Vector3 = escena.interior.posicion_local(otro)
	var desde := Vector3(punto.x * 0.5, -0.28, punto.z + 0.6)
	escena.interior.recolocar(jugador, Transform3D(Basis(), desde))
	jugador.orientar(atan2(-(objetivo.x - desde.x), -(objetivo.z - desde.z)))
	jugador.comandos.accion_rol = true


## Si la parada tiene puesto de dulces, lleva al vendedor junto a él (en la calle).
func _ir_al_puesto(escena: Node, jugador: CuerpoPersonaje) -> bool:
	var interior: InteriorCamion = escena.interior
	var puerta: Vector3 = escena.camion.global_transform * GestorPasajeros.PUERTA_UMBRAL
	for puesto: Vector3 in escena.puestos:
		if puesto.distance_to(puerta) > 15.0:
			continue
		interior.llevar_a(jugador, false)
		jugador.global_position = puesto + Vector3.UP * 0.05
		for _k in 3:
			await get_tree().physics_frame
		return escena.vendedor.mercancia == ParametrosRoles.cargar().mercancia
	return false


## Con la puerta cerrada, un golpe hacia la puerta no saca a nadie del camión.
func _probar_puerta_cerrada() -> void:
	print("La puerta cerrada:")
	Juego.en_partida = false
	Juego.nueva_partida(SEMILLA, "cobrador")
	Ruta.bots_activos = []
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	var interior: InteriorCamion = escena.interior
	var jugador: CuerpoPersonaje = escena.jugador
	for _k in 30:
		await get_tree().physics_frame
	interior.fijar_puerta(false)
	interior.recolocar(jugador, Transform3D(Basis(), Vector3(0.55, -0.28, -3.15)))
	await get_tree().physics_frame
	escena.ragdolls.desplomar(Vector3(7.0, 2.0, 0.0), jugador)
	var siempre_adentro := true
	for _k in 3 * FPS:
		await get_tree().physics_frame
		for activo in escena.ragdolls.activos:
			if not interior.esta_dentro(activo.ragdoll):
				siempre_adentro = false
	_verificar(siempre_adentro, "un golpe hacia la puerta cerrada no saca a nadie")
	escena.queue_free()
	Ruta.bots_activos = null
	Ruta.eventos_activos = null
	await get_tree().physics_frame
	await get_tree().physics_frame
