extends Node
## Prueba automática de la etapa 3: pasajeros que suben y bajan en las paradas, ragdolls con
## tope de activos, el camión lleno (15 pasajeros) en modo loco sin que la física se dispare, y
## el jugador sentado en un asiento libre (D44).
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa3.tscn
## Sale con código 0 si todo pasa.

const ESCENA := "res://escenas/interior_prueba/interior_prueba.tscn"
const FPS := 60

var _fallos: int = 0
## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 16
var _verificaciones: int = 0

var escena: Node
var interior: InteriorCamion
var camion: Camion
var piloto: PilotoAutomatico
var pasajeros: GestorPasajeros
var ragdolls: GestorRagdolls


func _ready() -> void:
	await _ruta_con_paradas()
	await _camion_lleno()
	await _jugador_sentado()
	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 3: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 3: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


func _abrir() -> void:
	escena = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	interior = escena.interior
	camion = escena.camion
	piloto = escena.piloto
	pasajeros = escena.pasajeros
	ragdolls = escena.ragdolls
	escena.set_physics_process(false)
	piloto.fijar_semilla(7)
	pasajeros.fijar_semilla(7)
	# El jugador se queda sujeto en el fondo, lejos de la puerta.
	interior.recolocar(escena.jugador, Transform3D(Basis(), Vector3(0.0, -0.28, 3.4)))
	escena.jugador.comandos.sujetarse = true


func _cerrar() -> void:
	escena.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _ruta_con_paradas() -> void:
	print("Una vuelta y media con paradas, chofer en modo normal:")
	await _abrir()
	piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	var paradas_visitadas := {}
	var max_a_bordo := 0
	var max_esperando := 0
	piloto.llego_a_parada.connect(func(k): paradas_visitadas[k] = true)
	var tiempo := 0.0
	var problemas := 0
	while tiempo < 200.0:
		escena.jugador.comandos.sujetarse = true
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
		max_a_bordo = maxi(max_a_bordo, pasajeros.a_bordo())
		problemas += _contar_problemas()
		if OS.get_cmdline_user_args().has("detalle") and fmod(tiempo, 2.0) < 1.0 / FPS:
			var estados := {}
			for pas in pasajeros.pasajeros:
				var nombre: String = GestorPasajeros.Estado.keys()[pas.estado]
				estados[nombre] = estados.get(nombre, 0) + 1
			print("        [%.0f s] parada del chofer %d, detectada %d, %.1f km/h | %s" % [tiempo, piloto.parada_actual, pasajeros.parada_actual, camion.velocidad_adelante * 3.6, estados])
	print("        paradas visitadas %d | subieron %d | bajaron %d | se perdieron %d | máximo a bordo %d | ragdolls %d" % [paradas_visitadas.size(), pasajeros.total_subieron, pasajeros.total_bajaron, pasajeros.total_perdidos, max_a_bordo, ragdolls.total_desplomes])
	_verificar(paradas_visitadas.size() >= 5, "el chofer se detiene en todas las paradas")
	_verificar(pasajeros.total_subieron >= 4, "suben pasajeros en las paradas (%d)" % pasajeros.total_subieron)
	_verificar(pasajeros.total_bajaron >= 2, "bajan pasajeros en su parada (%d)" % pasajeros.total_bajaron)
	_verificar(max_a_bordo <= 15, "nunca hay más de 15 a bordo (máximo %d)" % max_a_bordo)
	_verificar(problemas == 0, "ningún pasajero atravesó el piso ni salió disparado (%d cuadros con problemas)" % problemas)
	await _cerrar()


func _camion_lleno() -> void:
	print("Camión lleno (15 pasajeros), chofer en modo loco, 40 s:")
	await _abrir()
	pasajeros.vaciar_paradas()
	pasajeros.llegadas_activas = false
	pasajeros.llenar(15)
	piloto.detenerse_en_paradas = false
	await _esperar(3.0)
	_verificar(pasajeros.a_bordo() == 15, "15 pasajeros a bordo (%d)" % pasajeros.a_bordo())
	piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	var tiempos: Array[float] = []
	var max_ragdolls := 0
	var problemas := 0
	var antes := Time.get_ticks_usec()
	for _k in 40 * FPS:
		escena.jugador.comandos.sujetarse = true
		await get_tree().physics_frame
		var ahora := Time.get_ticks_usec()
		tiempos.append((ahora - antes) / 1000.0)
		antes = ahora
		max_ragdolls = maxi(max_ragdolls, ragdolls.activos.size())
		problemas += _contar_problemas()
	tiempos.sort()
	var promedio := 0.0
	for t in tiempos:
		promedio += t
	promedio /= tiempos.size()
	var p95 := tiempos[int(tiempos.size() * 0.95)]
	print("        tiempo de CPU por cuadro (física + lógica, sin dibujar): promedio %.2f ms, 95%% de los cuadros bajo %.2f ms" % [promedio, p95])
	print("        ragdolls: %d en total, máximo %d al mismo tiempo | se perdieron %d" % [ragdolls.total_desplomes, max_ragdolls, pasajeros.total_perdidos])
	_verificar(max_ragdolls <= interior.parametros.max_ragdolls, "respeta el tope de ragdolls activos (%d de %d)" % [max_ragdolls, interior.parametros.max_ragdolls])
	_verificar(problemas == 0, "ningún pasajero atravesó el piso ni salió disparado (%d cuadros con problemas)" % problemas)
	# El promedio es estable; el 95 % depende de lo que esté haciendo la computadora en ese momento.
	_verificar(promedio < 8.0, "la simulación cabe de sobra en un cuadro de 16.7 ms (promedio %.2f ms)" % promedio)

	print("Un golpe fuerte saca a un pasajero por la puerta:")
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	await _esperar(3.0)
	# Después del modo loco el camión puede quedar torcido o pegado a algo: se pone derecho en su carril.
	escena._reiniciar()
	interior.recolocar(escena.jugador, Transform3D(Basis(), Vector3(0.0, -0.28, 3.4)))
	await _esperar(3.0)
	var de_pie: CuerpoPersonaje = null
	var su_lugar := Vector3.ZERO
	for p in pasajeros.pasajeros:
		if p.estado == GestorPasajeros.Estado.DE_PIE and not p.cuerpo.desplomado:
			de_pie = p.cuerpo
			su_lugar = p.lugar.punto
	_verificar(de_pie != null, "hay pasajeros de pie, sujetos del pasamanos")
	if de_pie != null:
		var perdidos_antes := pasajeros.total_perdidos
		# Lo levanta a la altura de la ventana y lo avienta hacia la izquierda (coordenadas del camión).
		# Junto a la puerta, con un golpe hacia afuera (+X en coordenadas del camión).
		de_pie.position = Vector3(0.55, -0.28, -3.15)
		ragdolls.desplomar(Vector3(7.0, 2.0, 0.0), de_pie)
		await _esperar(1.5)
		print("        el ragdoll quedó en %s (coordenadas del camión), adentro: %s" % [interior.posicion_local(ragdolls.activos[0].ragdoll).snapped(Vector3.ONE * 0.1) if not ragdolls.activos.is_empty() else "-", interior.esta_dentro(ragdolls.activos[0].ragdoll) if not ragdolls.activos.is_empty() else "-"])
		await _esperar(6.5)
		_verificar(pasajeros.total_perdidos > perdidos_antes, "sale volando por la puerta y se pierde (perdidos %d)" % pasajeros.total_perdidos)
	await _cerrar()


func _jugador_sentado() -> void:
	print("El jugador se sienta en un asiento libre (D44):")
	await _abrir()
	pasajeros.llegadas_activas = false
	pasajeros.vaciar()
	piloto.detenerse_en_paradas = false
	var jugador: CuerpoPersonaje = escena.jugador
	# En el pasillo, junto a la tercera fila del lado derecho (asiento en x = 1.03, z = 0.38).
	interior.recolocar(jugador, Transform3D(Basis(), Vector3(0.3, -0.28, 0.4)))
	await _esperar(1.0)
	jugador.comandos.sentarse = true
	await _esperar(0.5)
	var donde := interior.posicion_local(jugador)
	_verificar(jugador.sentado and donde.x > 0.8 and absf(donde.z - 0.38) < 0.1, "se sienta en el asiento de junto (%s)" % donde.snapped(Vector3.ONE * 0.01))
	pasajeros.llenar(12)
	var en_asiento := pasajeros.pasajeros.filter(func(p): return p.lugar.get("asiento", false)).size()
	_verificar(en_asiento == 11, "los pasajeros no le ganan su asiento (%d de 12 asientos para ellos)" % en_asiento)
	piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	await _esperar(8.0)
	var velocidad := camion.velocidad_adelante * 3.6
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	await _esperar(3.0)
	_verificar(jugador.sentado and not jugador.desplomado, "sentado aguanta el modo loco y un frenazo a %.0f km/h" % velocidad)
	jugador.comandos.sentarse = true
	await _esperar(1.0)
	donde = interior.posicion_local(jugador)
	_verificar(not jugador.sentado and jugador.is_on_floor() and interior.esta_dentro(jugador) and absf(donde.x) < 0.6, "se para en el pasillo (%s)" % donde.snapped(Vector3.ONE * 0.01))
	# Junto a la puerta no hay ningún asiento al alcance: no pasa nada.
	interior.recolocar(jugador, Transform3D(Basis(), Vector3(0.0, -0.28, -2.6)))
	await _esperar(1.0)
	jugador.comandos.sentarse = true
	await _esperar(0.5)
	_verificar(not jugador.sentado, "lejos de los asientos no se sienta")
	await _cerrar()


func _esperar(segundos: float) -> void:
	for _k in roundi(segundos * FPS):
		escena.jugador.comandos.sujetarse = true
		await get_tree().physics_frame


## Cuenta pasajeros con señales de error de física: hundidos bajo el piso del camión o volando
## a velocidades absurdas (más de 40 m/s respecto al camión).
func _contar_problemas() -> int:
	var problemas := 0
	for p in pasajeros.pasajeros:
		var cuerpo: CuerpoPersonaje = p.cuerpo
		if not is_instance_valid(cuerpo) or cuerpo.desplomado or cuerpo.sentado:
			continue
		if interior.esta_dentro(cuerpo):
			if cuerpo.position.y < -0.8 or cuerpo.velocity.length() > 40.0:
				problemas += 1
		elif cuerpo.global_position.y < -2.0:
			problemas += 1
	return problemas
