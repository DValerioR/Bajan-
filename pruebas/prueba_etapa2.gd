extends Node
## Prueba automática de la etapa 2: caminar dentro del camión en movimiento (interior separado, D35).
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa2.tscn
## Sale con código 0 si todo pasa.

const ESCENA := "res://escenas/interior_prueba/interior_prueba.tscn"
const FPS := 60

var _fallos: int = 0
## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 12
var _verificaciones: int = 0
var escena: Node
var jugador: CuerpoPersonaje
var interior: InteriorCamion
var camion: Camion
var piloto: PilotoAutomatico

# Mediciones de la situación en curso.
var _posicion_anterior := Vector3.INF
var _salto_maximo: float = 0.0
var _salio: bool = false
var _tropiezos: int = 0
var _estaba_tropezando: bool = false
var _hundimiento: float = 0.0


func _ready() -> void:
	await _probar()
	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 2: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 2: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


func _probar() -> void:
	escena = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	jugador = escena.jugador
	interior = escena.interior
	camion = escena.camion
	piloto = escena.piloto
	escena.set_physics_process(false)
	piloto.fijar_semilla(2026)
	# Esta prueba es del interior vacío: sin pasajeros ni paradas.
	escena.pasajeros.vaciar()
	escena.pasajeros.llegadas_activas = false
	piloto.detenerse_en_paradas = false
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	await _esperar(1.0, func(): pass)

	print("Parado, sin tocar nada:")
	var inicio := _local()
	await _esperar(2.0, func(): pass)
	_verificar(_local().distance_to(inicio) < 0.1, "no se desliza con el camión parado (%.3f m)" % _local().distance_to(inicio))
	_verificar(jugador.is_on_floor(), "está parado en el piso del camión")

	print("Caminar de la puerta al fondo con el chofer en modo normal:")
	piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	await _esperar(6.0, func(): pass)
	_limpiar_medidas()
	var tiempo := 0.0
	while _local().z < 3.0 and tiempo < 25.0 and interior.esta_dentro(jugador):
		jugador.comandos.mover = Vector2(_corregir_rumbo(), 1.0)
		await get_tree().physics_frame
		_medir()
		tiempo += 1.0 / FPS
	jugador.comandos.mover = Vector2.ZERO
	_verificar(_local().z >= 3.0, "llega al fondo (z = %.2f m) en %.1f s, a %.0f km/h" % [_local().z, tiempo, camion.velocidad_adelante * 3.6])
	_reportar()
	_verificar(not _salio and _salto_maximo < 0.25 and _hundimiento < 0.12, "sin fallos de física al caminar")

	print("Modo loco, sujeto del pasamanos, 20 s:")
	# Se prepara con el camión parado: junto a la puerta abierta y sin sujetarse, un frenazo lo
	# puede sacar volando (desde la etapa 3).
	escena._reiniciar()
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	await _esperar(1.0, func(): pass)
	await _ir_a(Vector3(0.0, 0.0, 0.0))
	piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	await _esperar(5.0, func(): jugador.comandos.sujetarse = true)
	inicio = _local()
	_limpiar_medidas()
	await _esperar(20.0, func(): jugador.comandos.sujetarse = true)
	jugador.comandos.sujetarse = false
	_verificar(not _salio and _local().distance_to(inicio) < 1.5, "sujeto, aguanta el modo loco (se movió %.2f m)" % _local().distance_to(inicio))
	_reportar()

	print("Modo loco, sin sujetarse, 20 s:")
	inicio = _local()
	_limpiar_medidas()
	await _esperar(20.0, func(): pass)
	print("        se movió %.2f m del lugar donde estaba" % _local().distance_to(inicio))
	_reportar()
	_verificar(_salto_maximo < 0.25 and _hundimiento < 0.12, "sin fallos de física con sustos")

	print("Frenazo en seco sin sujetarse:")
	# Si con los sustos salió volando, se espera a que se levante antes de regresarlo al camión.
	for _k in 10 * FPS:
		if not jugador.desplomado:
			break
		await get_tree().physics_frame
	escena._reiniciar()
	piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	# Frena en cuanto va a buena velocidad (más de 42 km/h, o a los 8 s).
	for _k in 8 * FPS:
		if camion.velocidad_adelante * 3.6 > 42.0:
			break
		await get_tree().physics_frame
		_medir()
	var desplomes_antes: int = escena.ragdolls.total_desplomes
	var velocidad_frenazo := camion.velocidad_adelante * 3.6
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	await _esperar(2.0, func(): pass)
	_verificar(escena.ragdolls.total_desplomes > desplomes_antes, "un frenazo a %.0f km/h lo tumba como ragdoll" % velocidad_frenazo)
	await _esperar(7.0, func(): pass)
	_verificar(not jugador.desplomado and jugador.is_on_floor(), "se vuelve a levantar (adentro: %s)" % interior.esta_dentro(jugador))

	print("Lanzar una bolsa por la ventana:")
	escena._reiniciar()
	piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	await _esperar(6.0, func(): pass)
	var bolsa: ObjetoSuelto = escena.objetos[1]
	interior.recolocar(bolsa, Transform3D(Basis(), Vector3(-0.9, 1.3, 0.65)))
	await get_tree().physics_frame
	# Dentro del camión la velocidad es relativa a él: hacia la ventana izquierda.
	bolsa.linear_velocity = Vector3(-6.0, 1.0, 0.0)
	# Se mide la velocidad justo en el cuadro en que la bolsa queda en la calle.
	var velocidad_salida := Vector3.INF
	var velocidad_camion := Vector3.ZERO
	for _k in FPS:
		await get_tree().physics_frame
		if velocidad_salida == Vector3.INF and not interior.esta_dentro(bolsa):
			velocidad_salida = bolsa.linear_velocity
			velocidad_camion = camion.linear_velocity
	var fuera := not interior.esta_dentro(bolsa)
	_verificar(fuera, "la bolsa sale por la ventana y queda en la calle")
	if velocidad_salida != Vector3.INF:
		var relativa := camion.global_basis.inverse() * (velocidad_salida - velocidad_camion)
		print("        al salir: bolsa %.1f m/s, camión %.1f m/s; velocidad respecto al camión %s" % [velocidad_salida.length(), velocidad_camion.length(), relativa.snapped(Vector3.ONE * 0.1)])
		_verificar(relativa.x < -3.0 and absf(relativa.z) < 3.0, "sale con la velocidad del camión más la del lanzamiento hacia la izquierda")

	print("Bajar por la puerta y volver a subir (camión parado):")
	escena._reiniciar()
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	await _esperar(2.0, func(): pass)
	jugador.orientar(-PI / 2.0)
	tiempo = 0.0
	while interior.esta_dentro(jugador) and tiempo < 6.0:
		jugador.comandos.mover = Vector2(0.0, 1.0)
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	await _esperar(0.4, func(): jugador.comandos.mover = Vector2(0.0, 1.0))
	jugador.comandos.mover = Vector2.ZERO
	await _esperar(0.5, func(): pass)
	var afuera := not interior.esta_dentro(jugador)
	_verificar(afuera and jugador.is_on_floor(), "baja por la puerta y queda parado en la calle (%.2f m del camión)" % (_local().x - 1.25))
	tiempo = 0.0
	while not interior.esta_dentro(jugador) and tiempo < 8.0:
		jugador.comandos.mover = Vector2(0.0, -1.0)
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	await _esperar(1.0, func(): jugador.comandos.mover = Vector2(0.0, -1.0))
	jugador.comandos.mover = Vector2.ZERO
	await _esperar(0.5, func(): pass)
	_verificar(interior.esta_dentro(jugador) and jugador.is_on_floor(), "vuelve a subir por los escalones (en %.1f s, z = %.2f, piso %.2f)" % [tiempo, _local().z, _local().y])

	escena.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


## Posición del jugador en coordenadas del camión.
func _local() -> Vector3:
	return interior.posicion_local(jugador)


## Corrige el volante del jugador para que siga el pasillo (x = 0).
func _corregir_rumbo() -> float:
	return clampf(_local().x * 2.0, -1.0, 1.0)


func _ir_a(destino: Vector3) -> void:
	var tiempo := 0.0
	while Vector2(_local().x - destino.x, _local().z - destino.z).length() > 0.3 and tiempo < 10.0:
		var falta := destino - _local()
		jugador.comandos.mover = Vector2(falta.x, falta.z).limit_length(1.0) * Vector2(-1.0, 1.0)
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	jugador.comandos.mover = Vector2.ZERO


func _esperar(segundos: float, control: Callable) -> void:
	for _k in roundi(segundos * FPS):
		control.call()
		await get_tree().physics_frame
		_medir()


func _limpiar_medidas() -> void:
	_posicion_anterior = Vector3.INF
	_salto_maximo = 0.0
	_salio = false
	_tropiezos = 0
	_hundimiento = 0.0


func _medir() -> void:
	var local := _local()
	# Mientras anda hecho ragdoll (y al levantarse donde quedó) no cuenta como brinco de física.
	if jugador.desplomado:
		_posicion_anterior = Vector3.INF
		return
	# En la calle, su posición respecto al camión cambia con lo que avanza el camión: no es un brinco.
	if not interior.esta_dentro(jugador):
		if not _salio:
			print("        salió del camión en %s (coordenadas del camión)" % local.snapped(Vector3.ONE * 0.01))
		_salio = true
		_posicion_anterior = Vector3.INF
		return
	if _posicion_anterior != Vector3.INF:
		_salto_maximo = maxf(_salto_maximo, local.distance_to(_posicion_anterior))
	_posicion_anterior = local
	# El piso del camión está en y = -0.3 (coordenadas del camión). Solo se mide sobre el piso: en
	# los escalones de la puerta o cayendo junto al camión todavía cuenta como adentro (hay margen).
	if absf(local.x) < 1.4 and absf(local.z) < 3.9:
		_hundimiento = maxf(_hundimiento, -0.3 - local.y)
	var tropezando := jugador.tropezando > 0.0
	if tropezando and not _estaba_tropezando:
		_tropiezos += 1
	_estaba_tropezando = tropezando


func _reportar() -> void:
	print("        escalones subidos (total) %d" % jugador.escalones_subidos)
	print("        tropiezos %d | brinco máximo de un cuadro %.3f m | se hundió en el piso %.3f m | se salió del camión: %s" % [_tropiezos, _salto_maximo, _hundimiento, "sí" if _salio else "no"])
