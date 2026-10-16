extends Node
## Prueba automática de la etapa 4: dinero, generador de rutas y una ruta completa.
## - El fondo nunca queda en negativo y, al cumplir la cuota, no baja de lo que tenía al empezar
##   la ruta (miles de operaciones al azar).
## - El generador hace rutas distintas, con 6 a 10 paradas, sin repetir zona más de dos veces
##   seguidas y sin que la calle se cruce consigo misma.
## - Una ruta de principio a fin, cobrando, se cierra contra la cuota; sin cobrar, se pierde.
## - Al caer, al cobrador se le riega el morral en monedas que se pueden recoger.
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa4.tscn

const ESCENA := "res://escenas/ruta/ruta.tscn"
const Ruta := preload("res://escenas/ruta/ruta.gd")
const FPS := 60

var _fallos: int = 0
## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 17
var _verificaciones: int = 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("solo_ruta"):
		await _probar_ruta_cobrando()
		get_tree().quit()
		return
	_probar_dinero()
	_probar_generador()
	await _probar_calle_libre()
	await _probar_ruta_cobrando()
	await _probar_ruta_sin_cobrar()
	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 4: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 4: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


# --- Dinero -----------------------------------------------------------------

func _probar_dinero() -> void:
	print("Dinero (50 partidas al azar):")
	var azar := RandomNumberGenerator.new()
	azar.seed = 4
	var negativo := false
	var bajo_al_cumplir := false
	var reaparicion_mal := false
	var rutas := 0
	for _partida in 50:
		var d := EstadoDinero.new()
		d.empezar_partida(80, 0.5)
		for numero in range(1, 8):
			d.empezar_ruta(60 + 30 * (numero - 1))
			for _op in azar.randi_range(5, 60):
				match azar.randi() % 4:
					0, 1:
						d.ingresar(azar.randi_range(1, 30))
					2:
						d.penalizar(azar.randi_range(1, 60))
					3:
						var antes := d.fondo
						var pudo := d.pagar_reaparicion(20)
						if pudo != (antes >= 20) or (not pudo and d.fondo != antes):
							reaparicion_mal = true
				if d.fondo < 0:
					negativo = true
			var cumplida := d.cerrar_ruta()
			rutas += 1
			if cumplida and d.fondo < d.fondo_al_empezar_ruta:
				bajo_al_cumplir = true
			if d.fondo < 0:
				negativo = true
			if not cumplida:
				break
			d.gastar(azar.randi_range(0, d.fondo))
	_verificar(not negativo, "el fondo nunca queda en negativo (%d rutas)" % rutas)
	_verificar(not bajo_al_cumplir, "al cumplir la cuota, el fondo no baja de lo que tenía al empezar la ruta")
	_verificar(not reaparicion_mal, "la penalización de reaparecer solo se cobra si alcanza completa")


# --- Generador ----------------------------------------------------------------

func _probar_generador() -> void:
	print("Generador de rutas (30 semillas):")
	var formas := {}
	var paradas_bien := true
	var zonas_bien := true
	var sin_cruces := true
	var topes_lejos := true
	for semilla in 30:
		var d := GeneradorRuta.generar(semilla, 1 + semilla % 4)
		formas[str(d.tramos)] = true
		var n: int = d.paradas.size()
		if n < 6 or n > 10:
			paradas_bien = false
		# Zonas: nunca la misma tres veces seguidas (sin contar la salida).
		var zonas: Array = d.zonas.slice(1).map(func(z): return z[1])
		for i in range(2, zonas.size()):
			if zonas[i] == zonas[i - 1] and zonas[i] == zonas[i - 2]:
				zonas_bien = false
		for parada in d.paradas:
			for tope in d.topes:
				if absf(float(tope) - float(parada)) < GeneradorRuta.DISTANCIA_LIBRE_PARADA - 0.01:
					topes_lejos = false
		if _se_cruza(d.segmentos):
			sin_cruces = false
	_verificar(formas.size() >= 25, "rutas distintas: %d de 30 semillas" % formas.size())
	_verificar(paradas_bien, "todas tienen entre 6 y 10 paradas")
	_verificar(zonas_bien, "ninguna repite zona más de dos veces seguidas")
	_verificar(topes_lejos, "ningún tope queda junto a una parada")
	_verificar(sin_cruces, "ninguna ruta se cruza consigo misma")


## Arma la calle de varias rutas y pasa una caja del ancho de la calle, a la altura del camión,
## por toda la ruta: no debe chocar con nada (edificios, árboles, postes o la banca de una parada).
func _probar_calle_libre() -> void:
	var invadidas := []
	for semilla in [11, 1, 2, 3, 4, 5]:
		var calle := Calle.new()
		calle.descripcion = GeneradorRuta.generar(semilla, 1 + semilla % 4)
		add_child(calle)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var caja := BoxShape3D.new()
		caja.size = Vector3(calle.ancho_carril * 2.0, 2.0, 0.5)
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = caja
		var espacio := get_viewport().world_3d.direct_space_state
		# Sin contar los últimos metros, donde está la barrera del final.
		for i in calle.puntos.size() - 3:
			consulta.transform = Transform3D(Basis.looking_at(calle.direcciones[i], Vector3.UP), calle.puntos[i] + Vector3.UP * 1.6)
			if not espacio.intersect_shape(consulta, 1).is_empty():
				invadidas.append("semilla %d, metro %d" % [semilla, i])
				break
		calle.free()
		await get_tree().physics_frame
	_verificar(invadidas.is_empty(), "nada invade la calle en 6 rutas generadas %s" % ("" if invadidas.is_empty() else str(invadidas)))


## Traza la ruta y revisa que dos puntos lejanos en la ruta nunca queden a menos de 25 m.
func _se_cruza(segmentos: Array) -> bool:
	var puntos: Array[Vector2] = []
	var posicion := Vector2.ZERO
	var rumbo := 0.0
	for s in segmentos:
		if s[0] == "recta":
			for k in int(s[1] / 2.0):
				posicion += Vector2(sin(rumbo), -cos(rumbo)) * 2.0
				puntos.append(posicion)
		else:
			var largo := absf(deg_to_rad(float(s[2]))) * float(s[1])
			var pasos := maxi(1, int(largo / 2.0))
			for k in pasos:
				rumbo -= deg_to_rad(float(s[2])) / pasos
				posicion += Vector2(sin(rumbo), -cos(rumbo)) * (largo / pasos)
				puntos.append(posicion)
	for i in puntos.size():
		for j in range(i + 30, puntos.size(), 3):
			if puntos[i].distance_to(puntos[j]) < 25.0:
				return true
	return false


# --- Ruta completa ---------------------------------------------------------------

func _abrir_ruta(semilla: int) -> Node:
	Juego.en_partida = false
	Ruta.semilla_forzada = semilla
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	escena.piloto.fijar_semilla(semilla)
	escena.pasajeros.fijar_semilla(semilla)
	return escena


func _probar_ruta_cobrando() -> void:
	print("Una ruta de principio a fin, cobrando a todos:")
	var escena: Node = await _abrir_ruta(11)
	var paradas: int = escena.calle.paradas.size()
	var fondo_inicial: int = Juego.dinero.fondo
	var tiempo := 0.0
	var regado_probado := false
	while not escena.terminada and tiempo < 600.0:
		# Como un jugador razonable, va sujeto del pasamanos.
		escena.jugador.comandos.sujetarse = true
		# "Cobrador de prueba": se pone frente a quien no ha pagado y le cobra.
		if Engine.get_physics_frames() % 30 == 0 and escena.interior.esta_dentro(escena.jugador) and not escena.jugador.desplomado:
			_cobrar_a_alguien(escena)
		# A media ruta, una caída con el morral lleno riega monedas.
		if not regado_probado and escena.cobrador.morral >= 12 and escena.pasajeros.parada_actual < 0:
			regado_probado = true
			await _probar_monedas(escena)
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
		if OS.get_cmdline_user_args().has("detalle") and Engine.get_physics_frames() % (20 * FPS) == 0:
			var piloto: PilotoAutomatico = escena.piloto
			print("        [%.0f s] índice %d de %d | %.0f km/h | modo %s | parada %d (piloto %d, última %d) | terminal %s | a bordo %d" % [tiempo, piloto._indice, escena.calle.puntos.size(), escena.camion.velocidad_adelante * 3.6, PilotoAutomatico.NOMBRES[piloto.modo], escena.pasajeros.parada_actual, piloto.parada_actual, piloto._ultima_parada, piloto.en_terminal, escena.pasajeros.a_bordo()])
	var r: Dictionary = escena.resultado
	_verificar(escena.terminada, "la ruta termina en la terminal (%.0f s, %d paradas)" % [tiempo, paradas])
	if escena.terminada:
		print("        ganancia $%d, cuota $%d, cobrados %d, sin pagar %d, regado $%d, perdido $%d" % [r.ganancia, r.cuota, r.cobrados, r.sin_pagar, r.regado, r.perdido])
		_verificar(r.cumplida, "cobrando a todos se cumple la cuota de la primera ruta")
		_verificar(r.fondo == fondo_inicial + r.ganancia - r.cuota, "el fondo cuadra: $%d = $%d inicial + $%d ganancia - $%d cuota" % [r.fondo, fondo_inicial, r.ganancia, r.cuota])
		_verificar(Juego.en_partida, "con la cuota cumplida, la partida sigue")
	escena.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _cobrar_a_alguien(escena: Node) -> void:
	var pasajeros: GestorPasajeros = escena.pasajeros
	for p in pasajeros.pasajeros:
		if p.pagado or not pasajeros._a_bordo(p) or p.cuerpo.desplomado or not escena.interior.esta_dentro(p.cuerpo):
			continue
		var objetivo: Vector3 = p.cuerpo.position
		var desde := Vector3(0.0, -0.28, objetivo.z + 0.9)
		escena.interior.recolocar(escena.jugador, Transform3D(Basis(), desde))
		escena.jugador.orientar(atan2(-(objetivo.x - desde.x), -(objetivo.z - desde.z)))
		escena.jugador.comandos.cobrar = true
		return


func _probar_monedas(escena: Node) -> void:
	var cobrador: Cobrador = escena.cobrador
	var antes := cobrador.morral
	escena.ragdolls.desplomar(Vector3(0.0, 1.0, 1.0), escena.jugador)
	await get_tree().physics_frame
	_verificar(cobrador.morral == 0 and cobrador.monedas_en_el_piso() > 0, "al caer se le riega todo el morral ($%d en %d monedas)" % [antes, cobrador.monedas_en_el_piso()])
	# Se levanta y recoge las monedas pasando sobre ellas.
	for _k in 8 * FPS:
		await get_tree().physics_frame
		if not escena.jugador.desplomado:
			break
	var recogido_antes := cobrador.morral
	for datos in cobrador._monedas.duplicate():
		if not is_instance_valid(datos.moneda):
			continue
		var moneda: ObjetoSuelto = datos.moneda
		if escena.interior.esta_dentro(moneda) and escena.interior.esta_dentro(escena.jugador):
			escena.interior.recolocar(escena.jugador, Transform3D(Basis(), Vector3(moneda.position.x, -0.28, moneda.position.z)))
			await get_tree().physics_frame
			await get_tree().physics_frame
	_verificar(cobrador.morral > recogido_antes or cobrador.monedas_en_el_piso() == 0, "las monedas se recogen pasando sobre ellas (morral $%d)" % cobrador.morral)


func _probar_ruta_sin_cobrar() -> void:
	print("Una ruta sin cobrarle a nadie:")
	var escena: Node = await _abrir_ruta(12)
	var tiempo := 0.0
	while not escena.terminada and tiempo < 600.0:
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	_verificar(escena.terminada and not escena.resultado.get("cumplida", true), "sin cobrar no se alcanza la cuota")
	_verificar(not Juego.en_partida, "sin cumplir la cuota, la partida termina")
	_verificar(escena.resultado.get("sin_pagar", 0) > 0, "los que se bajaron sin pagar cuentan como dinero perdido (%d)" % escena.resultado.get("sin_pagar", 0))
	escena.queue_free()
	await get_tree().physics_frame
