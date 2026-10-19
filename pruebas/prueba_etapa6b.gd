extends Node
## Prueba automática de la etapa 6B (por partes, D48).
## 6B1, "Tírame paro":
## - el rol al empezar es distinto del que tuvo al empezar la partida anterior;
## - en cada parada (salvo la primera y la terminal) los puestos rotan: el jugador cambia de rol,
##   cada quien camina a su puesto y la ventana de esa parada se alarga;
## - el camión nunca se mueve sin nadie al volante;
## - si al jugador le toca manejar y no se sienta, el bot vuelve al volante y la ruta sigue.
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa6b.tscn [-- detalle]

const ESCENA := "res://escenas/ruta/ruta.tscn"
const Ruta := preload("res://escenas/ruta/ruta.gd")
const FPS := 60
const SEMILLA := 5

## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 13
var _fallos: int = 0
var _verificaciones: int = 0
var _detalle := false


## El "jugador" de la prueba: camina a su puesto (y si es chofer, al volante) como lo haría una
## persona. Es un bot del interior puesto sobre el cuerpo del jugador.
class CaminaAlPuesto:
	extends BotInterior

	func pensar(_delta: float) -> void:
		if caminar_hacia(puesto, 1.0, 0.4):
			cuerpo.comandos.sujetarse = true


func _ready() -> void:
	_detalle = OS.get_cmdline_user_args().has("detalle")
	_probar_rol_inicial()
	await _probar_rotacion(true)
	await _probar_rotacion(false)
	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 6B: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 6B: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


func _probar_rol_inicial() -> void:
	print("Rol al empezar en \"Tírame paro\":")
	var distinto := true
	var vistos := {}
	for anterior in Juego.ROLES:
		for _k in 40:
			var r := Juego.rol_para_empezar_paro(anterior)
			vistos[r] = true
			if r == anterior:
				distinto = false
	_verificar(distinto, "nunca empieza con el mismo rol que la vez anterior")
	_verificar(vistos.size() == Juego.ROLES.size(), "puede empezar con cualquiera de los cuatro roles")


## `maneja`: si el jugador se sienta al volante cuando le toca (si no, el bot debe recuperarlo).
func _probar_rotacion(maneja: bool) -> void:
	print("Ruta en \"Tírame paro\", %s:" % ("el jugador va a cada puesto que le toca" if maneja else "el jugador nunca se sienta al volante"))
	Juego.en_partida = false
	Juego.nueva_partida(SEMILLA, "cobrador", "paro")
	Ruta.semilla_forzada = SEMILLA
	Ruta.eventos_activos = []
	Ruta.bots_activos = null
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.piloto.fijar_semilla(SEMILLA)
	escena.pasajeros.fijar_semilla(SEMILLA)
	var pasajeros: GestorPasajeros = escena.pasajeros
	var camion: Camion = escena.camion
	var jugador: CuerpoPersonaje = escena.jugador
	# El "jugador" de la prueba camina derecho: que no se atore con los pasajeros de pie (una
	# persona los rodearía).
	jugador.atravesar_personajes(true)
	var roles_del_jugador: Array[String] = [escena.rol]
	var cerebro: BotInterior
	var rol_del_cerebro := ""
	var sin_chofer_andando := 0.0
	var max_sin_chofer_andando := 0.0
	var ventana_alargada := pasajeros.duracion_ventana() > Juego.parametros.ventana
	var siempre_alguien := true
	var tiempo := 0.0
	var manejo_el_jugador := false
	var parada_vista := -1
	while not escena.terminada and tiempo < 1200.0:
		for nombre in ["EntradaJugador", "EntradaChofer"]:
			if escena.has_node(nombre):
				escena.get_node(nombre).queue_free()
		if escena.rol != roles_del_jugador[-1]:
			roles_del_jugador.append(escena.rol)
		# El cerebro del "jugador" según su rol de ahora.
		if escena.rol != rol_del_cerebro:
			if cerebro != null:
				cerebro.queue_free()
				cerebro = null
			rol_del_cerebro = escena.rol
			if escena.rol == "chofer":
				if maneja:
					cerebro = BotChofer.new()
			else:
				cerebro = CaminaAlPuesto.new()
			if cerebro != null:
				cerebro.cuerpo = jugador
				cerebro.pasajeros = pasajeros
				cerebro.puesto = Ruta.PUESTOS[escena.rol]
				escena.add_child(cerebro)
		# Al volante, el jugador "maneja" con el piloto automático y abre la puerta en las paradas.
		if pasajeros.al_volante == jugador:
			manejo_el_jugador = true
			if not escena.piloto.activo:
				var parada := pasajeros.parada_actual
				escena.piloto.tomar_volante(parada, escena._ultima_parada, maxf(2.0, pasajeros.duracion_ventana() - pasajeros.tiempo_en_parada) if parada >= 0 else 0.0)
				escena.piloto.activo = true
				escena.piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
			if pasajeros.parada_actual >= 0 and not escena.interior.puerta_abierta:
				camion.comandos.puerta = true
		# Nunca se mueve sin nadie al volante.
		if pasajeros.al_volante == null and absf(camion.velocidad_adelante) > 0.5:
			sin_chofer_andando += 1.0 / FPS
			max_sin_chofer_andando = maxf(max_sin_chofer_andando, sin_chofer_andando)
		else:
			sin_chofer_andando = 0.0
		for r in ["chofer", "cobrador", "voceador"]:
			if escena.ocupante(r) == null:
				siempre_alguien = false
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
		if _detalle and pasajeros.parada_actual != parada_vista:
			parada_vista = pasajeros.parada_actual
			print("        [%.0f s] parada %d | rol %s | al volante %s | rotaciones %d | piloto activo %s" % [tiempo, parada_vista, escena.rol, pasajeros.al_volante.name if pasajeros.al_volante != null else "-", escena.rotaciones, escena.piloto.activo])
		if _detalle and Engine.get_physics_frames() % (20 * FPS) == 0:
			print("        [%.0f s] parada %d | rol %s | al volante %s | rotaciones %d | %.0f km/h" % [tiempo, pasajeros.parada_actual, escena.rol, pasajeros.al_volante.name if pasajeros.al_volante != null else "-", escena.rotaciones, camion.velocidad_adelante * 3.6])

	var paradas: int = escena.calle.paradas.size()
	_verificar(escena.terminada, "la ruta llega a la terminal y se cierra (%.0f s, %d paradas)" % [tiempo, paradas])
	_verificar(escena.rotaciones == paradas - 2, "los puestos rotan en cada parada salvo la primera y la terminal (%d rotaciones)" % escena.rotaciones)
	_verificar(ventana_alargada, "la ventana de parada se alarga para el cambio de puestos (%.0f s)" % pasajeros.duracion_ventana())
	_verificar(max_sin_chofer_andando < 1.0, "el camión nunca anda sin nadie al volante (máximo %.1f s)" % max_sin_chofer_andando)
	_verificar(siempre_alguien, "el chofer, el cobrador y el voceador siempre tienen a alguien")
	_verificar(escena.volantes_rescatados == 0, "el bot chofer siempre llega caminando al volante (rescates: %d)" % escena.volantes_rescatados)
	if maneja:
		var cambios_seguidos := true
		for i in range(1, roles_del_jugador.size()):
			if roles_del_jugador[i] == roles_del_jugador[i - 1]:
				cambios_seguidos = false
		_verificar(roles_del_jugador.size() >= paradas - 1 and cambios_seguidos, "el jugador cambia de rol en cada rotación: %s" % " → ".join(roles_del_jugador))
		_verificar(manejo_el_jugador and escena.volantes_recuperados == 0, "cuando le toca, el jugador se sienta al volante y maneja")
	else:
		_verificar(escena.volantes_recuperados > 0 and roles_del_jugador.has("chofer"), "si no se sienta, el bot vuelve al volante (%d veces) y la ruta sigue" % escena.volantes_recuperados)
	if cerebro != null:
		cerebro.queue_free()
	escena.queue_free()
	Ruta.eventos_activos = null
	Juego.modo = "normal"
	await get_tree().physics_frame
	await get_tree().physics_frame
