extends Node
## Prueba automática de la etapa 6B (por partes, D48).
## 6B1, "Tírame paro":
## - el rol al empezar es distinto del que tuvo al empezar la partida anterior;
## - en cada parada (salvo la primera y la terminal) los puestos rotan: el jugador cambia de rol,
##   cada quien camina a su puesto y la ventana de esa parada se alarga;
## - el camión nunca se mueve sin nadie al volante;
## - si al jugador le toca manejar y no se sienta, el bot vuelve al volante y la ruta sigue.
## 6B2, el chofer sale volando (en los dos modos):
## - el camión sigue de inercia y se va frenando poco a poco, sin detenerse en seco;
## - la gente se desespera y, a los pocos segundos, un bot de a bordo deja su puesto y maneja;
## - en la siguiente parada se cobra "el chofer no entregó el camión" una sola vez;
## - Modo normal: el chofer reaparece y retoma el volante; el bot vuelve a su puesto.
## - "Tírame paro": el chofer reaparece y entra a la rotación (ya no maneja).
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa6b.tscn [-- detalle]

const ESCENA := "res://escenas/ruta/ruta.tscn"
const Ruta := preload("res://escenas/ruta/ruta.gd")
const FPS := 60
const SEMILLA := 5

## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 27
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
	await _probar_chofer_sale_volando("normal")
	await _probar_chofer_sale_volando("paro")
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
	# La red de seguridad (poner al bot junto al volante si se atora) puede saltar alguna vez: la
	# física con ragdolls no sale idéntica en cada corrida. Más de una vez por ruta ya es un problema.
	_verificar(escena.volantes_rescatados <= 1, "el bot chofer llega caminando al volante (rescates: %d)" % escena.volantes_rescatados)
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


func _probar_chofer_sale_volando(modo: String) -> void:
	print("El chofer sale volando (%s):" % ("Modo normal" if modo == "normal" else "\"Tírame paro\""))
	Juego.en_partida = false
	Juego.nueva_partida(SEMILLA, "chofer", modo)
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
	var interior: InteriorCamion = escena.interior
	var jugador: CuerpoPersonaje = escena.jugador
	jugador.atravesar_personajes(true)
	# El "jugador": maneja con el piloto (como en la rotación) y, si lo tumban, camina de vuelta al
	# volante. En "Tírame paro", si le toca otro rol, camina a su puesto.
	var cerebro: BotInterior
	var rol_del_cerebro := ""
	var tiempo := 0.0
	var tumbado := false
	var salio_del_camion := false
	var velocidad_al_salir := 0.0
	var max_frenado := 0.0
	var velocidad_anterior := 0.0
	var tiempo_hasta_sustituto := -1.0
	var desesperacion_max := 0.0
	var sustituto_rol := ""
	var sustituto: CuerpoPersonaje = null
	var fondo_antes := 0
	var parada_del_incidente := -1
	var penalizaciones_en_esa_parada := 0
	var rol_despues := ""
	var al_volante_despues: CuerpoPersonaje = null
	var bot_regreso_a_su_puesto := false
	var parada_salida := -1
	while not escena.terminada and tiempo < 900.0:
		for nombre in ["EntradaJugador", "EntradaChofer"]:
			if escena.has_node(nombre):
				escena.get_node(nombre).queue_free()
		if escena.rol != rol_del_cerebro:
			if cerebro != null:
				cerebro.queue_free()
			rol_del_cerebro = escena.rol
			cerebro = BotChofer.new() if escena.rol == "chofer" else CaminaAlPuesto.new()
			cerebro.cuerpo = jugador
			cerebro.pasajeros = pasajeros
			cerebro.puesto = Ruta.PUESTOS[escena.rol]
			escena.add_child(cerebro)
		if pasajeros.al_volante == jugador:
			if not escena.piloto.activo:
				var parada := pasajeros.parada_actual
				escena.piloto.tomar_volante(parada, escena._ultima_parada, maxf(2.0, pasajeros.duracion_ventana() - pasajeros.tiempo_en_parada) if parada >= 0 else 0.0)
				escena.piloto.activo = true
				escena.piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
			if pasajeros.parada_actual >= 0 and not interior.puerta_abierta:
				camion.comandos.puerta = true
		# Ya en camino (en "Tírame paro", antes de la primera rotación), a toda velocidad: un golpe
		# saca al chofer por la ventana.
		if not tumbado and escena._ultima_parada >= 0 and pasajeros.parada_actual < 0 and camion.velocidad_adelante > 9.0 and pasajeros.al_volante == jugador:
			tumbado = true
			parada_salida = escena._ultima_parada
			velocidad_al_salir = camion.velocidad_adelante
			fondo_antes = Juego.dinero.fondo
			escena.ragdolls.desplomar(Vector3(-10.0, 15.0, 1.0), jugador)
			# Sale por la ventana del chofer: el ragdoll pasa a la calle, justo afuera, cayendo hacia
			# atrás. Que se salga por ahí con la física ya lo prueba la etapa 3; aquí importa lo que sigue.
			for activo in escena.ragdolls.activos:
				if activo.cuerpo == jugador:
					interior.llevar_a(activo.ragdoll, false)
					var afuera: Vector3 = camion.global_transform * Vector3(-2.2, 1.0, -3.0)
					var desplazamiento: Vector3 = afuera - activo.ragdoll.centro()
					for parte in activo.ragdoll.cuerpos():
						parte.global_position += desplazamiento
						parte.linear_velocity = camion.linear_velocity * 0.6
		if tumbado and parada_del_incidente < 0:
			for activo in escena.ragdolls.activos:
				if activo.cuerpo == jugador and not interior.esta_dentro(activo.ragdoll):
					salio_del_camion = true
			if not jugador.desplomado and not interior.esta_dentro(jugador):
				salio_del_camion = true
			# Frenado promedio en cada medio segundo sin nadie al volante (y aún andando).
			if pasajeros.al_volante == null and Engine.get_physics_frames() % (FPS / 2) == 0:
				if velocidad_anterior > 0.5:
					max_frenado = maxf(max_frenado, (velocidad_anterior - camion.velocidad_adelante) * 2.0)
				velocidad_anterior = camion.velocidad_adelante
			desesperacion_max = maxf(desesperacion_max, pasajeros.desesperacion)
			if tiempo_hasta_sustituto < 0.0 and pasajeros.al_volante != null and pasajeros.al_volante != jugador:
				tiempo_hasta_sustituto = tiempo
				sustituto_rol = escena._rol_del_sustituto
				sustituto = pasajeros.al_volante
			if pasajeros.parada_actual >= 0 and pasajeros.parada_actual > parada_salida:
				parada_del_incidente = pasajeros.parada_actual
		# Lo que pasa en la parada del incidente, ya con el camión quieto un rato.
		if parada_del_incidente >= 0 and rol_despues == "" and pasajeros.parada_actual == parada_del_incidente and pasajeros.tiempo_en_parada > 4.0:
			penalizaciones_en_esa_parada = escena.penalizaciones_chofer
			rol_despues = escena.rol
			al_volante_despues = pasajeros.al_volante
			# Vuelve a su puesto; en "Tírame paro" la rotación de esa parada puede darle otro (D21).
			bot_regreso_a_su_puesto = sustituto != null and Juego.ROLES.any(func(r): return escena.ocupante(r) == sustituto) and (modo == "paro" or escena.ocupante(sustituto_rol) == sustituto)
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	_verificar(tumbado and salio_del_camion, "un golpe saca al chofer jugador por la ventana (a %.0f km/h)" % (velocidad_al_salir * 3.6))
	_verificar(max_frenado > 0.0 and max_frenado < 4.0, "sin chofer, el camión se va frenando poco a poco (frenado máximo %.1f m/s²)" % max_frenado)
	_verificar(desesperacion_max > 0.0, "la gente se desespera mientras nadie maneja (%.0f %%)" % (desesperacion_max * 100.0))
	_verificar(sustituto_rol in ["cobrador", "voceador"], "un bot de a bordo deja su puesto y toma el volante (el %s)" % sustituto_rol)
	_verificar(penalizaciones_en_esa_parada == 1 and escena.penalizaciones_chofer == 1, "en la siguiente parada se cobra \"el chofer no entregó el camión\" una sola vez (%d)" % escena.penalizaciones_chofer)
	_verificar(bot_regreso_a_su_puesto, "el bot que manejó vuelve a tener un puesto%s" % (" (en Modo normal, el suyo)" if modo == "normal" else ""))
	if modo == "normal":
		_verificar(rol_despues == "chofer" and al_volante_despues == jugador, "el chofer reaparece y retoma el volante (%s, al volante %s)" % [rol_despues, al_volante_despues.name if al_volante_despues else "nadie"])
	else:
		_verificar(rol_despues != "chofer" and al_volante_despues != jugador, "el chofer reaparece y entra a la rotación: ahora es %s" % rol_despues)
	_verificar(escena.terminada, "la ruta llega a la terminal (%.0f s)" % tiempo)
	if cerebro != null:
		cerebro.queue_free()
	escena.queue_free()
	Ruta.eventos_activos = null
	Juego.modo = "normal"
	await get_tree().physics_frame
	await get_tree().physics_frame

