class_name BotInterior
extends Node
## Cerebro de un bot del interior (DISEÑO.md, sección 5.2; etapa 6A): llena los ComandosPersonaje
## de su cuerpo como lo haría un jugador. El cuerpo es el mismo que el de cualquier personaje, así
## que recibe los mismos empujones, se cae y se levanta igual. El interior es casi un pasillo: el
## bot camina derecho a puntos fijos (en coordenadas del camión) y hace su acción.
## Ante un frenazo o una curva fuerte se sujeta del pasamanos, pero tarda en reaccionar y a veces
## no alcanza: es su peor desempeño. Los números van en config/roles.cfg.
## Cada rol lo concreta en `pensar()`.

@export var cuerpo: CuerpoPersonaje
@export var pasajeros: GestorPasajeros
## Dónde vuelve a aparecer si sale volando del camión (coordenadas del camión).
var puesto := Vector3(0.0, -0.28, 0.0)
## Puntos que recorre antes de su rol (coordenadas del camión): por ejemplo, para subir por la
## puerta desde la banqueta. Mientras los recorre no cuenta como "fuera del camión".
var por_recorrer: Array[Vector3] = []

var roles: ParametrosRoles
var azar := RandomNumberGenerator.new()
## Veces que salió del camión (para las pruebas).
var veces_fuera: int = 0

var _alerta: float = -1.0
var _falla: bool = false
var _agarrado: float = 0.0
var _fuera: float = 0.0
## Segundos caminando hacia el mismo punto de `por_recorrer` (si se atora, se lo salta).
var _en_el_punto: float = 0.0
var _parada_al_salir: int = -1


func _ready() -> void:
	# Antes que el cuerpo, como la entrada del jugador.
	process_physics_priority = -10
	roles = ParametrosRoles.cargar()
	Config.recargado.connect(func(): roles = ParametrosRoles.cargar())
	azar.randomize()


func _physics_process(delta: float) -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	var c := cuerpo.comandos
	c.mover = Vector2.ZERO
	c.sujetarse = false
	c.gritar = false
	if cuerpo.desplomado:
		return
	# Solo el chofer va al volante: si le tocó otro rol, se para.
	if pasajeros.al_volante == cuerpo and not maneja():
		pasajeros.dejar_volante(cuerpo)
	if not por_recorrer.is_empty():
		# Si el camión arranca y lo deja abajo, deja de perseguirlo: espera la siguiente parada.
		if not pasajeros.interior.esta_dentro(cuerpo) and pasajeros.parada_actual < 0 and absf(pasajeros.interior.camion.velocidad_adelante) > 2.0:
			por_recorrer.clear()
		else:
			while not por_recorrer.is_empty() and caminar_hacia(por_recorrer[0], 1.0, 0.4):
				por_recorrer.remove_at(0)
				_en_el_punto = 0.0
			_en_el_punto += delta
			if _en_el_punto > 5.0 and not por_recorrer.is_empty():
				por_recorrer.remove_at(0)
				_en_el_punto = 0.0
			return
	if _atender_salida(delta):
		return
	pensar(delta)
	# Al pensar puede haberse ido (el vendedor que se baja).
	if cuerpo != null and is_instance_valid(cuerpo):
		_cuidarse(delta)


## Lo que hace el rol en este cuadro. Se sobreescribe.
func pensar(_delta: float) -> void:
	pass


## Si este rol va al volante (el bot chofer).
func maneja() -> bool:
	return false


## Si el rol quiere ir sujeto aunque no haya empujones (el voceador en la puerta).
func quiere_sujetarse() -> bool:
	return false


## Ante un empujón fuerte quiere sujetarse: tarda en reaccionar y a veces no alcanza.
func _cuidarse(delta: float) -> void:
	var empujon := cuerpo.marco.empuje(cuerpo.global_position + cuerpo.up_direction * cuerpo.altura * 0.5)
	if empujon.length() >= roles.umbral_sujetarse:
		if _alerta < 0.0:
			_alerta = roles.reaccion_bot
			_falla = azar.randf() < roles.probabilidad_fallar
		_alerta -= delta
		if _alerta <= 0.0 and not _falla:
			_agarrado = 1.5
	else:
		_alerta = -1.0
	_agarrado = maxf(0.0, _agarrado - delta)
	if _agarrado > 0.0 or quiere_sujetarse():
		cuerpo.comandos.sujetarse = true


## Si salió del camión con el camión detenido en una parada y la puerta abierta, se vuelve a subir
## caminando. Si el camión ya se fue, espera a la siguiente parada y vuelve a su puesto (en la 6B
## esto cuesta la penalización de "bot fuera del camión"). Devuelve true mientras está afuera.
func _atender_salida(delta: float) -> bool:
	if pasajeros.interior.esta_dentro(cuerpo):
		_fuera = 0.0
		return false
	if _fuera == 0.0:
		veces_fuera += 1
		_parada_al_salir = pasajeros.parada_actual
	_fuera += delta
	if pasajeros.parada_actual >= 0 and pasajeros.interior.puerta_abierta:
		subir_por_la_puerta()
		return true
	var parada := pasajeros.parada_actual
	if _fuera > 1.5 and parada >= 0 and parada != _parada_al_salir:
		pasajeros.interior.recolocar(cuerpo, Transform3D(Basis(), puesto))
		cuerpo.orientar(PI)
		_fuera = 0.0
	return true


## Camina hacia un punto (coordenadas del camión). Devuelve true si ya llegó.
func caminar_hacia(destino: Vector3, rapidez: float = 1.0, llegada: float = 0.35) -> bool:
	var objetivo := pasajeros.interior.desde_local(cuerpo, destino)
	var diferencia := objetivo - cuerpo.global_position
	diferencia -= cuerpo.up_direction * diferencia.dot(cuerpo.up_direction)
	if diferencia.length() < llegada:
		return true
	var giro := atan2(-diferencia.x, -diferencia.z)
	var t := 1.0 - exp(-8.0 * get_physics_process_delta_time())
	cuerpo.orientar(lerp_angle(cuerpo.giro_actual(), giro, t))
	var alineado := clampf(1.0 - absf(angle_difference(cuerpo.giro_actual(), giro)) / PI, 0.2, 1.0)
	cuerpo.comandos.mover = Vector2(0.0, rapidez * roles.rapidez_bot * alineado)
	return false


## Voltea hacia un punto (en el espacio del cuerpo). Devuelve true si ya lo tiene enfrente.
func voltear_hacia(punto: Vector3) -> bool:
	var diferencia := punto - cuerpo.global_position
	var giro := atan2(-diferencia.x, -diferencia.z)
	var t := 1.0 - exp(-10.0 * get_physics_process_delta_time())
	cuerpo.orientar(lerp_angle(cuerpo.giro_actual(), giro, t))
	return absf(angle_difference(cuerpo.giro_actual(), giro)) < 0.35


## Recorrido para subir por la puerta desde la banqueta hasta su puesto.
func subir_por_la_puerta() -> void:
	por_recorrer = [GestorPasajeros.PUERTA_AFUERA, GestorPasajeros.PUERTA_UMBRAL, GestorPasajeros.PUERTA_ADENTRO, puesto]
	# Si ya está en los escalones (entre la banqueta y la puerta), no baja: sube directo.
	if cuerpo != null and pasajeros.interior.posicion_local(cuerpo).x < GestorPasajeros.PUERTA_AFUERA.x - 0.3:
		por_recorrer.remove_at(0)
	_en_el_punto = 0.0


## Cuerpo nuevo de bot (o de jugador) con su figura, listo para agregarse al interior.
static func nuevo_cuerpo(nombre: String, modelo: String) -> CuerpoPersonaje:
	var cuerpo := CuerpoPersonaje.new()
	cuerpo.name = nombre
	cuerpo.parametros = ParametrosInterior.cargar()
	var visual := Personaje.new()
	visual.name = "Visual"
	visual.modelo = modelo
	cuerpo.add_child(visual)
	cuerpo.visual = visual
	return cuerpo
