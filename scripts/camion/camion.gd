class_name Camion
extends RigidBody3D
## Simulación del microbús: suspensión por rayos, motor, frenos, dirección y agarre arcade.
## Solo lee `comandos`; quien maneje (jugador, bot o red) llena esos comandos.
## Los números salen de config/conduccion.cfg (F9 los recarga en vivo).

## Se emite cuando el chofer pide enderezar el camión; la escena decide dónde ponerlo.
signal pide_reinicio
## Datos para la interfaz y los sonidos, una vez por cuadro de física.
signal telemetria(velocidad_kmh: float, ruedas_en_suelo: int)

var comandos := ComandosConduccion.new()
var parametros: ParametrosConduccion

## Posición actual del volante, de -1 (izquierda) a 1 (derecha), ya suavizada.
var volante: float = 0.0
## Velocidad hacia adelante (m/s); negativa en reversa.
var velocidad_adelante: float = 0.0
var ruedas_en_suelo: int = 0
## Aceleración en ejes del camión (m/s²), sin gravedad. La usa el balanceo visual.
var aceleracion_local := Vector3.ZERO

var _ruedas: Array[Dictionary] = []
var _velocidad_anterior := Vector3.ZERO
var _angulo_llantas: float = 0.0
var _claxon_sonando := false

@onready var _carroceria: Node3D = $Carroceria
@onready var _motor: AudioStreamPlayer = $SonidoMotor
@onready var _claxon: AudioStreamPlayer = $SonidoClaxon


func _ready() -> void:
	for anclaje in $Ruedas.get_children():
		_ruedas.append({
			"nodo": anclaje,
			"llanta": anclaje.get_node("Llanta"),
			"giro": anclaje.get_node("Llanta/Giro"),
			"anclaje_local": anclaje.position,
			"delantera": anclaje.name.begins_with("Delantera"),
			"motriz": anclaje.name.begins_with("Trasera"),
			"compresion": 0.0,
			"distancia": 0.0,
			"en_suelo": false,
			"velocidad_giro": 0.0,
		})
	_motor.stream = Sintetizador.motor()
	_claxon.stream = Sintetizador.claxon()
	_aplicar_parametros()
	Config.recargado.connect(_aplicar_parametros)
	_motor.play()


func _aplicar_parametros() -> void:
	parametros = ParametrosConduccion.cargar()
	mass = parametros.masa
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, parametros.centro_masa_y, 0.0)
	angular_damp = parametros.amortiguacion_angular
	_motor.volume_db = parametros.volumen_motor
	_claxon.volume_db = parametros.volumen_claxon
	for r in _ruedas:
		r.distancia = parametros.largo_reposo + parametros.radio_rueda


## Coloca el camión quieto en la transformación indicada (para reiniciar o aparecer).
func colocar(destino: Transform3D) -> void:
	global_transform = destino
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_velocidad_anterior = Vector3.ZERO
	volante = 0.0
	for r in _ruedas:
		r.compresion = 0.0
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var p := parametros
	if comandos.reiniciar:
		comandos.reiniciar = false
		pide_reinicio.emit()

	var arriba := global_basis.y
	var adelante := -global_basis.z
	velocidad_adelante = linear_velocity.dot(adelante)
	_actualizar_volante(delta)

	var masa_rueda := p.masa / _ruedas.size()
	var centro_masa_global := global_transform * center_of_mass
	var factor_velocidad := clampf(absf(velocidad_adelante) / p.velocidad_maxima, 0.0, 1.0)
	_angulo_llantas = volante * lerpf(p.angulo_maximo, p.angulo_a_velocidad_maxima, factor_velocidad)
	var espacio := get_world_3d().direct_space_state
	var largo := p.largo_reposo + p.radio_rueda
	ruedas_en_suelo = 0

	for r in _ruedas:
		var anclaje: Vector3 = global_transform * (r.anclaje_local as Vector3)
		var consulta := PhysicsRayQueryParameters3D.create(anclaje, anclaje - arriba * largo, 1, [get_rid()])
		var golpe := espacio.intersect_ray(consulta)
		if golpe.is_empty():
			r.en_suelo = false
			r.compresion = 0.0
			r.distancia = largo
			continue
		r.en_suelo = true
		ruedas_en_suelo += 1

		# Suspensión: resorte y amortiguador a lo largo del eje vertical del camión.
		var distancia := anclaje.distance_to(golpe.position)
		var compresion := largo - distancia
		var velocidad_compresion: float = (compresion - r.compresion) / delta
		r.compresion = compresion
		r.distancia = distancia
		var fuerza_suspension := maxf(0.0, compresion * p.rigidez + velocidad_compresion * p.amortiguacion) * masa_rueda
		apply_force(arriba * fuerza_suspension, anclaje - global_position)
		# Patada: si la llanta sube de golpe (tope, orilla de bache), la suspensión "toca fondo"
		# y esa esquina del camión sale empujada hacia arriba. Es lo que hace brincar al camión.
		if velocidad_compresion > p.umbral_patada and p.patada_topes > 0.0:
			var objetivo := minf((velocidad_compresion - p.umbral_patada) * p.patada_topes, p.patada_maxima)
			var esquina := linear_velocity + angular_velocity.cross(anclaje - centro_masa_global)
			var falta := objetivo - esquina.dot(arriba)
			if falta > 0.0:
				apply_impulse(arriba * falta * masa_rueda, anclaje - global_position)

		# Direcciones de la llanta sobre el piso (las delanteras giran con el volante).
		var normal: Vector3 = golpe.normal
		var base_llanta := global_basis
		if r.delantera:
			base_llanta = base_llanta.rotated(arriba, -_angulo_llantas)
		var frente := (-base_llanta.z).slide(normal).normalized()
		var lado := base_llanta.x.slide(normal).normalized()
		var velocidad_punto := linear_velocity + angular_velocity.cross(golpe.position - centro_masa_global)
		var velocidad_lateral := velocidad_punto.dot(lado)
		var velocidad_longitudinal := velocidad_punto.dot(frente)
		r.velocidad_giro = velocidad_longitudinal / p.radio_rueda

		# Agarre lateral: quita el derrape hasta el límite que aguanta la llanta.
		var agarre := p.lateral_delantero if r.delantera else p.lateral_trasero
		var limite := fuerza_suspension * p.coeficiente_maximo
		var fuerza_lateral := clampf(-velocidad_lateral * agarre * masa_rueda, -limite, limite)

		# Motor (tracción trasera), reversa, frenos y rodado.
		var fuerza_longitudinal := 0.0
		if r.motriz:
			if comandos.acelerar > 0.0 and velocidad_adelante > -0.5:
				# El empuje se acaba suave al acercarse a la velocidad máxima.
				var proporcion := velocidad_adelante / p.velocidad_maxima
				var disponible := clampf(1.0 - proporcion * proporcion, 0.0, 1.0)
				fuerza_longitudinal += comandos.acelerar * p.aceleracion * disponible * p.masa * 0.5
			elif comandos.frenar > 0.0 and velocidad_adelante < 0.8:
				var disponible := clampf(1.0 + velocidad_adelante / p.velocidad_maxima_reversa, 0.0, 1.0)
				fuerza_longitudinal -= comandos.frenar * p.aceleracion_reversa * disponible * p.masa * 0.5
		var freno := 0.0
		if comandos.frenar > 0.0 and velocidad_adelante >= 0.8:
			freno = comandos.frenar
		elif comandos.acelerar > 0.0 and velocidad_adelante <= -0.5:
			freno = comandos.acelerar
		if freno > 0.0:
			var desaceleracion := minf(freno * p.frenado, absf(velocidad_longitudinal) / delta)
			fuerza_longitudinal -= signf(velocidad_longitudinal) * desaceleracion * masa_rueda
		fuerza_longitudinal -= velocidad_longitudinal * p.resistencia_rodado * masa_rueda
		fuerza_longitudinal = clampf(fuerza_longitudinal, -limite * 1.5, limite * 1.5)

		var punto_fuerza := (golpe.position as Vector3).lerp(centro_masa_global, p.altura_fuerzas)
		apply_force(frente * fuerza_longitudinal + lado * fuerza_lateral, punto_fuerza - global_position)

	apply_central_force(-linear_velocity * linear_velocity.length() * p.resistencia_aire * p.masa)
	_estabilizar(arriba)

	var aceleracion := (linear_velocity - _velocidad_anterior) / delta
	_velocidad_anterior = linear_velocity
	aceleracion_local = global_basis.inverse() * aceleracion
	telemetria.emit(velocidad_adelante * 3.6, ruedas_en_suelo)


func _actualizar_volante(delta: float) -> void:
	var p := parametros
	var objetivo := clampf(comandos.girar, -1.0, 1.0)
	var rapidez := p.rapidez_volante
	if absf(objetivo) < absf(volante) or signf(objetivo) != signf(volante):
		rapidez = p.retorno_volante
	volante = move_toward(volante, objetivo, rapidez * delta)


## Endereza al camión si se ladea de más o va en el aire, para que voltearse sea raro.
func _estabilizar(arriba: Vector3) -> void:
	var p := parametros
	var inclinacion := arriba.angle_to(Vector3.UP)
	if inclinacion < p.inclinacion_limite and ruedas_en_suelo >= 2:
		return
	var eje := arriba.cross(Vector3.UP)
	if eje.length_squared() < 0.000001:
		eje = global_basis.z
	var exceso := maxf(inclinacion - p.inclinacion_limite, 0.0) + (0.15 if ruedas_en_suelo < 2 else 0.0)
	apply_torque(eje.normalized() * exceso * p.enderezar_fuerza * p.masa)


func _process(delta: float) -> void:
	var p := parametros
	# Llantas: suben y bajan con la suspensión, giran y las delanteras se orientan.
	for r in _ruedas:
		var llanta: Node3D = r.llanta
		llanta.position.y = -(float(r.distancia) - p.radio_rueda)
		if r.delantera:
			llanta.rotation.y = -_angulo_llantas
		var giro: Node3D = r.giro
		giro.rotation.x = wrapf(giro.rotation.x - float(r.velocidad_giro) * delta, -PI, PI)

	# Balanceo exagerado de la carrocería según cómo acelera el camión.
	var objetivo_lado := clampf(aceleracion_local.x * p.inclinacion_lateral_factor, -p.inclinacion_lateral_max, p.inclinacion_lateral_max)
	var objetivo_cabeceo := clampf(-aceleracion_local.z * p.cabeceo_factor, -p.cabeceo_max, p.cabeceo_max)
	var t := 1.0 - exp(-p.suavizado_visual * delta)
	_carroceria.rotation.z = lerpf(_carroceria.rotation.z, deg_to_rad(objetivo_lado), t)
	_carroceria.rotation.x = lerpf(_carroceria.rotation.x, deg_to_rad(objetivo_cabeceo), t)

	# Sonidos: el motor sube de tono con la velocidad y el acelerador.
	_motor.pitch_scale = 0.55 + 1.1 * absf(velocidad_adelante) / p.velocidad_maxima + 0.15 * comandos.acelerar
	if comandos.claxon and not _claxon_sonando:
		_claxon.play()
	elif not comandos.claxon and _claxon_sonando:
		_claxon.stop()
	_claxon_sonando = comandos.claxon
