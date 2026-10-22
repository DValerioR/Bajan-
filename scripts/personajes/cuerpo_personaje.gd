class_name CuerpoPersonaje
extends CharacterBody3D
## Cuerpo físico de un personaje que camina (jugador o, más adelante, bot o red).
## Solo lee `comandos`. Lo que siente del camión (gravedad aparente, empujones, giro) se lo dice
## su `marco`, así el mismo código sirve en la calle y dentro del camión.
##
## Modelo de inercia: la velocidad horizontal (respecto al piso) recibe el empujón del camión y
## una "firmeza" que la lleva hacia donde el personaje quiere caminar. Con un empujón fuerte y sin
## sujetarse, el personaje tropieza un momento; con uno muy fuerte (o un golpe directo) pide
## volverse ragdoll (`pide_desplomarse`), y GestorRagdolls decide si se puede.
## Sentado, no lo mueve nada: va pegado a su asiento. Colgado de la puerta (el voceador) es igual:
## va fijo en el escalón, agarrado del tubo, con el cuerpo asomado hacia afuera.

## El personaje recibió un empujón o golpe suficiente para caer como ragdoll.
signal pide_desplomarse(empujon: Vector3)
## Un golpe del camión lo arrancó del asiento (el chofer en un choque): se rompe el parabrisas.
signal arrancado_del_asiento

const CAPA_PERSONAJES := 8
const CAPA_OBJETOS := 16
## Altura máxima de escalón que sube caminando (banquetas, escalones del camión).
const PASO_MAXIMO := 0.35
const MASCARA := 1 | 4 | CAPA_PERSONAJES

var comandos := ComandosPersonaje.new()
var marco := MarcoMovimiento.new()
var parametros: ParametrosInterior
## Figura visual. Dentro del camión vive en un reflejo, fuera del cuerpo; aquí solo se anima.
var visual: Personaje

var altura: float = 1.7
var altura_ojos: float = 1.55
## Punto de vista: gira en vertical. En la calle, la cámara del jugador va aquí adentro.
var cabeza: Node3D

var sujetado: bool = false
var tropezando: float = 0.0
var empujon_actual := Vector3.ZERO
var en_suelo: bool = false
var cargado: RigidBody3D = null
## Cuántas veces ha subido un escalón (lo usan las pruebas).
var escalones_subidos: int = 0
## Mientras anda hecho ragdoll, el cuerpo se apaga y espera a levantarse.
var desplomado: bool = false
var sentado: bool = false
## Al volante: sentado con las manos en el volante, que se mueve con `volante` (de -1 a 1).
var manejando: bool = false
var volante: float = 0.0
## Sentado, una sacudida real del camión de al menos esto (m/s²: un choque, no un frenazo) lo
## arranca del asiento y sale volando. 0 = nunca (los pasajeros y el bot chofer, D23). El jugador
## chofer sí puede salir volando (5.3).
var umbral_salir_del_asiento: float = 0.0
## Colgado de la puerta (va también `sentado`, fijo en su lugar): se asoma hacia `hacia_afuera`
## (dirección en su espacio) y estira la mano libre a `mano_afuera` (en su espacio, INF = no la
## estira). Una sacudida de al menos `umbral_soltarse` lo avienta a la calle.
var colgado: bool = false
var hacia_afuera := Vector3.ZERO
var mano_afuera := Vector3.INF
var umbral_soltarse: float = 14.0
## Qué tanto va asomado ya (0 a 1): entra y sale suave, y la cabeza (la cámara) va con el cuerpo.
var asomado: float = 0.0

var _lugar_sentado := Transform3D()
var _mascara := MASCARA

var _giro: float = 0.0
var _vertical: float = 0.0
## Sentado, el cuerpo no gira: se voltea solo la cabeza (radianes, respecto al asiento).
var _giro_cabeza: float = 0.0
## Hasta dónde voltea la cabeza sentado (radianes).
const GIRO_CABEZA_SENTADO := deg_to_rad(110.0)


func _ready() -> void:
	collision_layer = CAPA_PERSONAJES
	# Mundo (1), interior del camión (4) y otros personajes (8). Los objetos chocan contra el
	# personaje (y él los va empujando al caminar), pero no lo frenan.
	collision_mask = _mascara
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	if parametros == null:
		parametros = ParametrosInterior.cargar()
	cabeza = Node3D.new()
	cabeza.name = "Cabeza"
	add_child(cabeza)
	configurar(altura, altura_ojos)


## Ajusta la cápsula y la cabeza al tamaño del personaje (origen entre los pies).
func configurar(nueva_altura: float, nueva_altura_ojos: float) -> void:
	altura = nueva_altura
	altura_ojos = nueva_altura_ojos
	var forma := get_node_or_null("Forma") as CollisionShape3D
	if forma == null:
		forma = CollisionShape3D.new()
		forma.name = "Forma"
		add_child(forma)
	var capsula := CapsuleShape3D.new()
	capsula.radius = parametros.radio if parametros else 0.27
	capsula.height = maxf(altura * 0.95, capsula.radius * 2.0 + 0.1)
	forma.shape = capsula
	forma.position = Vector3(0.0, capsula.height * 0.5, 0.0)
	if cabeza:
		cabeza.position = Vector3(0.0, altura_ojos, 0.0)


## Si atraviesa a los demás personajes (los pasajeros se escurren por el pasillo; el jugador
## sí choca contra ellos).
func atravesar_personajes(atravesar: bool) -> void:
	_mascara = (1 | 4) if atravesar else MASCARA
	if collision_layer != 0:
		collision_mask = _mascara


## Hacia dónde mira y gira (radianes): lo usa quien coloque al personaje.
func orientar(giro: float) -> void:
	_giro = giro


## El giro que corresponde a hacia dónde mira ahora, en su espacio actual
## (después de pasar entre el interior y la calle).
func giro_actual() -> float:
	var frente := -global_basis.z
	return atan2(-frente.x, -frente.z)


## Después de pasar entre el interior y la calle, sigue mirando hacia el mismo lado.
func al_cambiar_espacio() -> void:
	orientar(giro_actual())


## Empujón directo (un golpe, otro personaje que lo avienta): cambio de velocidad en m/s.
func empujar(cambio_velocidad: Vector3) -> void:
	if desplomado or sentado:
		return
	# Sujeto del pasamanos aguanta mucho mejor los golpes.
	if sujetado:
		cambio_velocidad *= minf(1.0, parametros.factor_sujetado * 2.0)
	if cambio_velocidad.length() >= parametros.umbral_golpe_ragdoll:
		pide_desplomarse.emit(cambio_velocidad)
		return
	velocity += cambio_velocidad
	tropezando = maxf(tropezando, parametros.duracion_tropiezo * 0.6)
	if visual:
		visual.sacudir(global_basis.inverse() * cambio_velocidad)
		# Al que empujan se enoja (y a veces se pone en guardia), si su modelo trae animaciones.
		visual.reproducir("pelear" if randf() < 0.35 else "enojo")


## Se sienta en `lugar` (pies del personaje ya en su lugar) y se queda ahí hasta `pararse()`.
func sentarse(lugar: Transform3D) -> void:
	sentado = true
	_lugar_sentado = lugar
	_soltar(Vector3.ZERO)
	collision_layer = 0
	collision_mask = 0
	# La cabeza sigue viendo hacia donde veía antes de sentarse.
	var frente_asiento := -lugar.basis.z
	_giro_cabeza = clampf(angle_difference(atan2(-frente_asiento.x, -frente_asiento.z), giro_actual()), -GIRO_CABEZA_SENTADO, GIRO_CABEZA_SENTADO)
	global_transform = lugar
	velocity = Vector3.ZERO
	orientar(giro_actual())
	reset_physics_interpolation()


## Se para en `lugar`, viendo hacia donde volteaba la cabeza (si iba sentado).
func pararse(lugar: Transform3D) -> void:
	var giro := giro_actual() + _giro_cabeza if sentado else giro_actual()
	sentado = false
	_descolgar()
	_enderezar_cabeza()
	collision_layer = CAPA_PERSONAJES
	collision_mask = _mascara
	global_transform = Transform3D(_base_con_arriba(up_direction, giro), lugar.origin)
	velocity = Vector3.ZERO
	orientar(giro)
	reset_physics_interpolation()


func _enderezar_cabeza() -> void:
	_giro_cabeza = 0.0
	if cabeza:
		cabeza.rotation.y = 0.0


## Se cuelga de la puerta en `lugar` (pies en el escalón), asomándose hacia `afuera` (dirección en
## su espacio). Se baja con `pararse()`.
func colgarse(lugar: Transform3D, afuera: Vector3) -> void:
	sentarse(lugar)
	colgado = true
	hacia_afuera = afuera.normalized()
	asomado = 0.0


func _descolgar() -> void:
	colgado = false
	asomado = 0.0
	mano_afuera = Vector3.INF
	if cabeza:
		cabeza.position = Vector3(0.0, altura_ojos, 0.0)
	if visual:
		visual.asomado = 0.0
		visual.estirar = Vector3.INF


## Se apaga mientras anda hecho ragdoll (lo llama GestorRagdolls).
func desplomar() -> void:
	desplomado = true
	# Si iba sentado, sale del asiento (al levantarse queda de pie donde caiga).
	sentado = false
	_descolgar()
	manejando = false
	_soltar(Vector3.ZERO)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if visual:
		visual.mostrar(false)


## Vuelve de ragdoll, parado en `lugar` (en el espacio donde quedó el ragdoll).
func levantar(lugar: Transform3D) -> void:
	desplomado = false
	sentado = false
	_enderezar_cabeza()
	collision_layer = CAPA_PERSONAJES
	collision_mask = _mascara
	global_transform = lugar
	velocity = Vector3.ZERO
	tropezando = 0.4
	orientar(giro_actual())
	reset_physics_interpolation()
	if visual:
		visual.mostrar(true)


func _physics_process(delta: float) -> void:
	var p := parametros
	if desplomado:
		return
	if sentado and umbral_salir_del_asiento > 0.0 and not colgado:
		var tiron := marco.sacudida(global_position + up_direction * altura * 0.5)
		if tiron.length() >= umbral_salir_del_asiento:
			arrancado_del_asiento.emit()
			pide_desplomarse.emit(tiron.limit_length(12.0) * 0.6 + up_direction * 3.0)
			if desplomado:
				return
	if colgado and umbral_soltarse > 0.0:
		# Colgado, un golpe fuerte lo suelta del tubo y sale para afuera.
		var tiron := marco.sacudida(global_position + up_direction * altura * 0.5)
		if tiron.length() >= umbral_soltarse:
			pide_desplomarse.emit(tiron.limit_length(12.0) * 0.6 + hacia_afuera * 4.0 + up_direction * 2.0)
			if desplomado:
				return
	if colgado:
		_animar_colgado(delta)
		return
	if sentado:
		global_transform = _lugar_sentado
		velocity = Vector3.ZERO
		# Sentado puede voltear a ver (el jugador); el cuerpo se queda viendo al frente.
		_giro_cabeza = clampf(_giro_cabeza + deg_to_rad(comandos.mirar.x), -GIRO_CABEZA_SENTADO, GIRO_CABEZA_SENTADO)
		_vertical = clampf(_vertical + deg_to_rad(comandos.mirar.y), deg_to_rad(-80.0), deg_to_rad(80.0))
		cabeza.rotation = Vector3(_vertical, _giro_cabeza, 0.0)
		comandos.mirar = Vector2.ZERO
		if visual:
			# Un frenazo o un volantazo fuerte asusta al que va sentado.
			if not manejando and marco.empuje(global_position + up_direction * altura * 0.5).length() > p.umbral_tropiezo:
				visual.reproducir("susto")
			visual.animar(delta, Vector3.ZERO, Vector3(volante, 0.0, 0.0), false, false, false, false, true, manejando)
		return

	# Vista: el giro horizontal mueve todo el cuerpo; el vertical, solo la cabeza.
	_giro += deg_to_rad(comandos.mirar.x) + marco.giro(delta)
	_vertical = clampf(_vertical + deg_to_rad(comandos.mirar.y), deg_to_rad(-80.0), deg_to_rad(80.0))
	comandos.mirar = Vector2.ZERO
	var arriba := marco.arriba(global_position)
	up_direction = arriba
	global_basis = _base_con_arriba(arriba, _giro)
	cabeza.rotation = Vector3(_vertical, 0.0, 0.0)

	# Empujones del camión, sujetarse y tropezar.
	en_suelo = is_on_floor()
	var empujon := marco.empuje(global_position + arriba * altura * 0.5)
	var agarre := marco.punto_de_agarre(global_position, altura * 1.25, p.alcance_pasamanos) if comandos.sujetarse else Vector3.INF
	sujetado = agarre.is_finite()
	if en_suelo and not sujetado and empujon.length() >= p.umbral_empujon_ragdoll:
		pide_desplomarse.emit(empujon * 0.35)
	if en_suelo and not sujetado and empujon.length() > p.umbral_tropiezo:
		tropezando = p.duracion_tropiezo
	elif sujetado and visual and empujon.length() > p.umbral_tropiezo:
		# Agarrado no se cae, pero se asusta.
		visual.reproducir("susto")
	tropezando = maxf(0.0, tropezando - delta)
	var aplicado := Vector3.ZERO
	if en_suelo or marco.empuje_en_aire():
		aplicado = empujon * (p.factor_sujetado if sujetado else 1.0)
	empujon_actual = aplicado

	# Velocidad horizontal: empujón + firmeza hacia donde quiere caminar.
	var vertical := arriba * velocity.dot(arriba)
	var horizontal := velocity - vertical
	var adelante := -global_basis.z
	var derecha := global_basis.x
	var deseo := (derecha * comandos.mover.x + adelante * comandos.mover.y).limit_length(1.0) * p.velocidad
	if tropezando > 0.0:
		deseo *= 0.2
	elif sujetado:
		deseo *= 0.5
	var firmeza := p.firmeza if en_suelo else p.firmeza * p.control_aire
	if sujetado:
		# Agarrado del pasamanos casi no lo arrastra nada.
		firmeza *= 4.0
	horizontal += (aplicado + (deseo - horizontal) * firmeza) * delta

	# Gravedad aparente (dentro del camión viene inclinada si el camión se inclina).
	var g := marco.gravedad(global_position)
	var g_vertical := arriba * g.dot(arriba)
	horizontal += (g - g_vertical) * delta
	vertical += g_vertical * delta
	if comandos.saltar:
		comandos.saltar = false
		if en_suelo and tropezando <= 0.0:
			vertical = arriba * p.salto
			apply_floor_snap()
	velocity = horizontal.limit_length(p.velocidad_maxima) + vertical
	move_and_slide()
	_subir_escalon(deseo * delta)

	_manejar_objetos(delta)
	if visual:
		var local_velocidad := global_basis.inverse() * horizontal
		var local_empujon := global_basis.inverse() * aplicado
		# La mano va a la agarradera (en las coordenadas de la figura, que son las del cuerpo).
		visual.agarre = global_transform.affine_inverse() * agarre if sujetado else Vector3.INF
		visual.animar(delta, local_velocidad, local_empujon, sujetado, cargado != null, tropezando > 0.0, not is_on_floor(), false)


## Colgado: fijo en el escalón, agarrado del tubo, asomado y con la mano libre estirada. Se mece con
## los empujones del camión y puede voltear a ver como sentado.
func _animar_colgado(delta: float) -> void:
	global_transform = _lugar_sentado
	velocity = Vector3.ZERO
	sujetado = true
	en_suelo = true
	_giro_cabeza = clampf(_giro_cabeza + deg_to_rad(comandos.mirar.x), -GIRO_CABEZA_SENTADO, GIRO_CABEZA_SENTADO)
	_vertical = clampf(_vertical + deg_to_rad(comandos.mirar.y), deg_to_rad(-80.0), deg_to_rad(80.0))
	comandos.mirar = Vector2.ZERO
	asomado = move_toward(asomado, 1.0, delta * 2.5)
	# La cabeza (y la cámara del jugador) va con el cuerpo asomado: gira sobre los pies.
	var afuera := global_basis.inverse() * hacia_afuera
	afuera.y = 0.0
	afuera = afuera.normalized()
	var angulo := Personaje.ANGULO_ASOMADO * asomado
	cabeza.position = afuera * altura_ojos * sin(angulo) + Vector3.UP * altura_ojos * cos(angulo)
	cabeza.rotation = Vector3(_vertical, _giro_cabeza, 0.0)
	if visual:
		var empujon := marco.empuje(global_position + up_direction * altura * 0.5)
		var agarre := marco.punto_de_agarre(global_position, altura * 1.25, parametros.alcance_pasamanos)
		visual.agarre = global_transform.affine_inverse() * agarre if agarre.is_finite() else Vector3.INF
		visual.asomado = asomado
		visual.asomar_hacia = afuera
		visual.estirar = global_transform.affine_inverse() * mano_afuera if mano_afuera.is_finite() else Vector3.INF
		visual.animar(delta, Vector3.ZERO, global_basis.inverse() * empujon * parametros.factor_sujetado, agarre.is_finite(), false, false, false)


## Si choca de frente con algo bajo (una banqueta, un escalón) mientras camina, lo sube.
func _subir_escalon(avance: Vector3) -> void:
	if not en_suelo or not is_on_wall() or avance.length() < 0.001:
		return
	# Solo se suben cosas fijas (banquetas, escalones), no objetos sueltos ni otros personajes.
	var contra_algo_fijo := false
	for i in get_slide_collision_count():
		var choque_pared := get_slide_collision(i)
		var normal := choque_pared.get_normal()
		var de_frente := normal.dot(avance.normalized()) < -0.5
		if absf(normal.dot(up_direction)) < 0.3 and de_frente and _es_fijo(choque_pared.get_collider()):
			contra_algo_fijo = true
	if not contra_algo_fijo:
		return
	var subida := up_direction * PASO_MAXIMO
	var paso := avance.normalized() * maxf(avance.length(), 0.08)
	var prueba := global_transform
	if test_move(prueba, subida):
		return
	prueba.origin += subida
	if test_move(prueba, paso):
		return
	prueba.origin += paso
	var choque := KinematicCollision3D.new()
	# Tiene que aterrizar sobre algo fijo y plano, no sobre la esquina de un asiento.
	if not test_move(prueba, -subida, choque) or not _es_fijo(choque.get_collider()) or choque.get_normal().dot(up_direction) < 0.85:
		return
	prueba.origin += choque.get_travel()
	escalones_subidos += 1
	global_transform = prueba
	reset_physics_interpolation()


static func _es_fijo(objeto: Object) -> bool:
	return objeto is StaticBody3D or objeto is AnimatableBody3D


## Base cuyo eje Y es `arriba` y que mira hacia `giro` alrededor de él.
func _base_con_arriba(arriba: Vector3, giro: float) -> Basis:
	var referencia := Vector3.FORWARD
	if absf(referencia.dot(arriba)) > 0.95:
		referencia = Vector3.RIGHT
	var frente := (referencia - arriba * referencia.dot(arriba)).normalized().rotated(arriba, giro)
	return Basis.looking_at(frente, arriba)


# --- Agarrar, lanzar y empujar ---------------------------------------------

func _manejar_objetos(delta: float) -> void:
	var p := parametros
	var mirada := -cabeza.global_basis.z
	if cargado != null and (not is_instance_valid(cargado) or cargado.get_world_3d() != get_world_3d()):
		cargado = null
	if comandos.agarrar:
		comandos.agarrar = false
		if cargado != null:
			_soltar(Vector3.ZERO)
		else:
			var golpe := _rayo(p.alcance)
			if golpe.get("collider") is RigidBody3D and golpe.collider.mass <= 90.0:
				cargado = golpe.collider
	if comandos.accion:
		comandos.accion = false
		if cargado != null:
			_soltar(mirada * p.velocidad_lanzamiento)
		else:
			var golpe := _rayo(p.alcance)
			var otro: Object = golpe.get("collider")
			if otro is RigidBody3D:
				# Empujón con la mano: a los objetos pesados los mueve menos.
				var cambio: float = p.empujon * minf(1.0, 25.0 / otro.mass)
				otro.apply_impulse(mirada * cambio * otro.mass, golpe.position - otro.global_position)
			elif otro is CuerpoPersonaje:
				otro.empujar(mirada * p.empujon)
	if cargado != null:
		var destino := cabeza.global_transform * Vector3(0.0, -0.3, -0.9)
		var separacion := destino - cargado.global_position
		if separacion.length() > 2.5:
			_soltar(Vector3.ZERO)
		else:
			cargado.linear_velocity = separacion / delta * 0.5 + get_real_velocity()
			cargado.angular_velocity *= 0.8


func _soltar(velocidad_extra: Vector3) -> void:
	if cargado != null and is_instance_valid(cargado):
		cargado.linear_velocity = get_real_velocity() + velocidad_extra
	cargado = null


func _rayo(alcance: float) -> Dictionary:
	var desde := cabeza.global_position
	var hasta := desde - cabeza.global_basis.z * alcance
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, CAPA_PERSONAJES | CAPA_OBJETOS, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(consulta)
