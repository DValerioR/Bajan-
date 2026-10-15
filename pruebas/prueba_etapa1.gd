extends Node
## Prueba automática de la etapa 1: un piloto de prueba maneja el camión con ComandosConduccion
## (sin teclado) y se mide que no se voltee, que acelere, frene y complete vueltas.
## Se corre con pruebas.bat; sale con código 0 si todo pasa.

const ESCENA := "res://escenas/calle_prueba/calle_prueba.tscn"
const FPS := 60

var _fallos: int = 0
## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 17
var _verificaciones: int = 0
var camion: Camion
var pista: PistaPrueba

# Estado del piloto de prueba y de las mediciones.
var _indice: int = -1
var _avance: float = 0.0
var _inclinacion_maxima: float = 0.0
var _volco: bool = false


func _ready() -> void:
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	escena.get_node("EntradaChofer").queue_free()
	camion = escena.camion
	pista = escena.pista
	await get_tree().physics_frame

	print("Calle de prueba:")
	var cierre := pista.puntos[pista.puntos.size() - 1].distance_to(pista.puntos[0])
	_verificar(cierre < 1.5, "el circuito cierra (%.2f m entre el final y la salida)" % cierre)
	_verificar(pista.longitud > 400.0, "longitud del circuito: %.0f m" % pista.longitud)

	await _prueba_reposo()
	await _prueba_arranque_y_frenado()
	await _prueba_vuelta(50.0, 4.0, 100.0, 30.0)
	await _prueba_vuelta(90.0, 7.0, 80.0, 60.0)
	await _prueba_volantazo()
	await _prueba_reinicio()

	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 1: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 1: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


# --- Pruebas --------------------------------------------------------------

func _prueba_reposo() -> void:
	print("Reposo:")
	_colocar_en(5.0)
	await _simular(3.0, func(): camion.comandos.limpiar())
	_verificar(camion.linear_velocity.length() < 0.3, "parado se queda quieto (%.2f m/s)" % camion.linear_velocity.length())
	_verificar(_inclinacion() < 3.0, "parado está derecho (%.1f°)" % _inclinacion())
	_verificar(camion.ruedas_en_suelo == 4, "las cuatro llantas tocan el piso")
	var altura := camion.global_position.y - pista.alto_calle
	_verificar(altura > 0.6 and altura < 1.3, "altura del chasis sobre la calle: %.2f m" % altura)


func _prueba_arranque_y_frenado() -> void:
	print("Arranque y frenado (en línea recta, terreno abierto):")
	_colocar_en_terreno_abierto()
	var tiempo := 0.0
	while camion.velocidad_adelante * 3.6 < 50.0 and tiempo < 12.0:
		camion.comandos.limpiar()
		camion.comandos.acelerar = 1.0
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	_verificar(tiempo < 6.0, "de 0 a 50 km/h en %.1f s" % tiempo)

	var inicio := camion.global_position
	var velocidad_inicial := camion.velocidad_adelante * 3.6
	tiempo = 0.0
	while camion.velocidad_adelante > 0.3 and tiempo < 8.0:
		camion.comandos.limpiar()
		camion.comandos.frenar = 1.0
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	var distancia := inicio.distance_to(camion.global_position)
	_verificar(distancia < 30.0, "frena de %.0f km/h a 0 en %.1f m (%.1f s)" % [velocidad_inicial, distancia, tiempo])

	# Con el freno presionado y el camión parado, mete reversa.
	await _simular(2.0, func():
		camion.comandos.limpiar()
		camion.comandos.frenar = 1.0)
	_verificar(camion.velocidad_adelante < -1.0, "con el camión parado, el freno mete reversa (%.1f km/h)" % (camion.velocidad_adelante * 3.6))


## Vuelta completa con el piloto, frenando antes de las curvas como lo haría un chofer normal.
func _prueba_vuelta(velocidad_kmh: float, aceleracion_lateral: float, tiempo_limite: float, inclinacion_permitida: float) -> void:
	print("Vuelta completa hasta %.0f km/h, curvas a %.1f m/s² (topes y baches incluidos):" % [velocidad_kmh, aceleracion_lateral])
	_colocar_en(5.0)
	_inclinacion_maxima = 0.0
	_volco = false
	var tiempo := 0.0
	var velocidad_maxima := 0.0
	var tiempo_en_el_aire := 0.0
	var avance_anterior := 0.0
	var tiempo_sin_avanzar := 0.0
	var reversas := 0
	while _avance < pista.longitud and tiempo < tiempo_limite:
		_pilotear(velocidad_kmh, aceleracion_lateral)
		# Como haría un chofer: si se atora contra algo, se echa en reversa y vuelve a intentar.
		if tiempo_sin_avanzar > 1.5:
			camion.comandos.girar = -camion.comandos.girar
			camion.comandos.acelerar = 0.0
			camion.comandos.frenar = 1.0
		if tiempo_sin_avanzar > 3.0:
			tiempo_sin_avanzar = 0.0
			reversas += 1
		await get_tree().physics_frame
		_medir()
		tiempo += 1.0 / FPS
		tiempo_sin_avanzar = 0.0 if _avance > avance_anterior else tiempo_sin_avanzar + 1.0 / FPS
		avance_anterior = maxf(avance_anterior, _avance)
		if reversas > 4:
			var lateral := (camion.global_position - pista.puntos[_indice]).dot(pista.derecha(_indice))
			printerr("        atorado en %.0f m: %.1f m del centro de la calle, %.1f km/h, inclinación %.1f°, llantas en el piso %d" % [_avance, lateral, camion.velocidad_adelante * 3.6, _inclinacion(), camion.ruedas_en_suelo])
			break
		velocidad_maxima = maxf(velocidad_maxima, camion.velocidad_adelante * 3.6)
		if camion.ruedas_en_suelo == 0:
			tiempo_en_el_aire += 1.0 / FPS
	_verificar(_avance >= pista.longitud, "completa la vuelta (%.0f de %.0f m en %.1f s, máx. %.0f km/h)" % [_avance, pista.longitud, tiempo, velocidad_maxima])
	_verificar(not _volco and _inclinacion_maxima < inclinacion_permitida, "no se voltea (inclinación máxima %.1f°, permitido %.0f°)" % [_inclinacion_maxima, inclinacion_permitida])
	print("        tiempo total en el aire: %.2f s; veces que tuvo que dar reversa: %d" % [tiempo_en_el_aire, reversas])


## Volantazo a fondo a 55 km/h en terreno abierto: puede derrapar, pero no debe quedar volteado.
func _prueba_volantazo() -> void:
	print("Volantazo a fondo:")
	_colocar_en_terreno_abierto()
	_inclinacion_maxima = 0.0
	_volco = false
	var tiempo := 0.0
	while camion.velocidad_adelante * 3.6 < 55.0 and tiempo < 10.0:
		camion.comandos.limpiar()
		camion.comandos.acelerar = 1.0
		await get_tree().physics_frame
		_medir()
		tiempo += 1.0 / FPS
	var velocidad := camion.velocidad_adelante * 3.6
	var lateral_maxima := [0.0]
	await _simular(3.0, func():
		camion.comandos.limpiar()
		camion.comandos.acelerar = 1.0
		camion.comandos.girar = 1.0
		lateral_maxima[0] = maxf(lateral_maxima[0], absf(camion.aceleracion_local.x)))
	print("        aceleración lateral máxima en el volantazo: %.1f m/s² (%.2f g)" % [lateral_maxima[0], lateral_maxima[0] / 9.8])
	await _simular(4.0, func(): camion.comandos.limpiar())
	_verificar(not _volco and _inclinacion_maxima < 55.0, "volantazo a %.0f km/h sin voltearse (inclinación máxima %.1f°)" % [velocidad, _inclinacion_maxima])
	_verificar(_inclinacion() < 8.0 and camion.ruedas_en_suelo == 4, "después del volantazo queda sobre sus cuatro llantas (%.1f°)" % _inclinacion())


func _prueba_reinicio() -> void:
	print("Reinicio:")
	var donde := pista.transform_en_indice(pista.indice_en_distancia(100.0))
	camion.colocar(Transform3D(donde.basis.rotated(donde.basis.z, PI), donde.origin + Vector3.UP * 2.0))
	await _simular(0.6, func(): camion.comandos.limpiar())
	var inclinacion_volteado := _inclinacion()
	camion.comandos.reiniciar = true
	for k in 8:
		await _simular(0.25, func(): camion.comandos.limpiar())
		print("        %.2f s después de R: inclinación %.1f°, llantas en el piso %d, altura %.2f m, velocidad %.2f m/s" % [(k + 1) * 0.25, _inclinacion(), camion.ruedas_en_suelo, camion.global_position.y, camion.linear_velocity.length()])
	_verificar(inclinacion_volteado > 90.0, "el camión estaba volteado (%.0f°)" % inclinacion_volteado)
	_verificar(_inclinacion() < 3.0 and camion.ruedas_en_suelo == 4, "R lo endereza sobre la calle (%.1f°)" % _inclinacion())


# --- Piloto de prueba y mediciones ---------------------------------------

func _colocar_en(distancia: float) -> void:
	_indice = pista.indice_en_distancia(distancia)
	_avance = 0.0
	camion.colocar(pista.transform_en_indice(_indice))


## Dentro del circuito hay terreno plano y libre de unos 70 × 100 m.
func _colocar_en_terreno_abierto() -> void:
	var centro := (pista.puntos[0] + pista.puntos[pista.puntos.size() / 2]) * 0.5
	camion.colocar(Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), Vector3(centro.x, 1.2, centro.z + 40.0)))
	await get_tree().physics_frame


func _simular(segundos: float, control: Callable) -> void:
	for _k in roundi(segundos * FPS):
		control.call()
		await get_tree().physics_frame
		_medir()


func _medir() -> void:
	var inclinacion := _inclinacion()
	_inclinacion_maxima = maxf(_inclinacion_maxima, inclinacion)
	if inclinacion > 90.0:
		_volco = true


func _inclinacion() -> float:
	return rad_to_deg(camion.global_basis.y.angle_to(Vector3.UP))


## Sigue el carril derecho mirando un punto adelante y ajusta la velocidad a las curvas.
func _pilotear(velocidad_kmh: float, aceleracion_lateral: float) -> void:
	var c := camion.comandos
	c.limpiar()
	var anterior := _indice
	_indice = pista.indice_cercano(camion.global_position, _indice)
	var paso := posmod(_indice - anterior, pista.puntos.size())
	if paso < pista.puntos.size() / 2:
		_avance += paso * PistaPrueba.PASO

	var velocidad := camion.velocidad_adelante
	var adelante := roundi(7.0 + maxf(velocidad, 0.0) * 0.6)
	var objetivo := pista.puntos[(_indice + adelante) % pista.puntos.size()]
	objetivo += pista.derecha(_indice + adelante) * pista.ancho_carril * 0.5
	var local := camion.global_transform.affine_inverse() * objetivo
	c.girar = clampf(atan2(local.x, -local.z) * 2.2, -1.0, 1.0)

	# Velocidad segura según la curva que viene: v = raíz(aceleración lateral × radio).
	var giro_adelante := 0.0
	for k in range(5, 35, 5):
		var a := pista.direcciones[(_indice + k) % pista.puntos.size()]
		var b := pista.direcciones[(_indice + k + 5) % pista.puntos.size()]
		giro_adelante = maxf(giro_adelante, a.angle_to(b))
	var radio := 5.0 / maxf(giro_adelante, 0.001)
	var objetivo_velocidad := minf(velocidad_kmh / 3.6, sqrt(aceleracion_lateral * radio))
	if velocidad < objetivo_velocidad - 0.5:
		c.acelerar = 1.0
	elif velocidad > objetivo_velocidad + 1.5:
		c.frenar = clampf((velocidad - objetivo_velocidad) / 5.0, 0.2, 1.0)
	else:
		c.acelerar = 0.35
