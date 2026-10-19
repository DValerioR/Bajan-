class_name BotVendedor
extends BotInterior
## Bot vendedor (etapa 6A): no viaja siempre a bordo (DISEÑO.md, sección 5.1). En algunas paradas
## sube con la caja llena, recorre el pasillo ofreciendo dulces (con el nodo Vendedor de la escena,
## el mismo que usa el jugador cuando es vendedor) y unas paradas después, o al acabarse la
## mercancía, se baja y se va. Mientras no viene a bordo no tiene cuerpo: este nodo lo crea al subir
## y lo quita al irse. En la rotación de "Tírame paro" puede recibir un cuerpo que ya va a bordo.

enum Estado { FUERA, SUBIENDO, VENDIENDO, BAJANDO, YENDOSE }

@export var ragdolls: GestorRagdolls
## El nodo del rol de vendedor (uno solo en la escena).
@export var vendedor: Vendedor
## Modelo de personaje del vendedor que sube.
var modelo: String = "vendedora"
## Apagado no sube a nadie (cuando el vendedor es el jugador).
var activo: bool = true

var estado: Estado = Estado.FUERA
## Totales de todas sus vueltas (para la interfaz y las pruebas).
var veces_subio: int = 0
var total_ventas: int = 0
var total_propinas: int = 0

var _paradas_restantes: int = 0
var _parada_anterior: int = -1
var _objetivo: CuerpoPersonaje
var _espera: float = 0.0
var _tiempo: float = 0.0
var _contador: int = 0


func _ready() -> void:
	super._ready()
	vendedor.vendio.connect(func(monto):
		if cuerpo != null and vendedor.cuerpo == cuerpo:
			total_ventas += 1
			total_propinas += monto)


func _physics_process(delta: float) -> void:
	var parada := pasajeros.parada_actual
	var llego := parada >= 0 and parada != _parada_anterior
	_parada_anterior = parada
	if estado == Estado.FUERA:
		if activo and llego and pasajeros.interior.puerta_abierta and not _es_terminal(parada) and azar.randf() < roles.vendedor_sube:
			_subir()
		return
	if llego:
		_paradas_restantes -= 1
	_tiempo += delta
	# Si el camión se fue mientras subía, o tarda mucho en bajar, se va.
	if (estado == Estado.SUBIENDO and _tiempo > 15.0 and not pasajeros.interior.esta_dentro(cuerpo)) or (estado == Estado.BAJANDO and _tiempo > 12.0):
		_irse()
	super._physics_process(delta)


## Le toca el rol a un cuerpo que ya va a bordo (rotación): sigue vendiendo con la caja que haya.
func tomar_cuerpo(nuevo: CuerpoPersonaje) -> void:
	cuerpo = nuevo
	vendedor.cuerpo = nuevo
	estado = Estado.VENDIENDO
	_paradas_restantes = azar.randi_range(int(roles.vendedor_paradas[0]), int(roles.vendedor_paradas[1]))
	_tiempo = 0.0


## Suelta el cuerpo sin quitarlo (le tocó otro rol): queda esperando, sin subir a nadie.
func soltar_cuerpo() -> void:
	if vendedor.cuerpo == cuerpo:
		vendedor.cuerpo = null
	cuerpo = null
	estado = Estado.FUERA


## Si ya está a bordo vendiendo (no subiendo ni yéndose).
func vendiendo() -> bool:
	return estado == Estado.VENDIENDO and cuerpo != null and pasajeros.interior.esta_dentro(cuerpo)


## Se baja y se va, venga como venga (el rol se lo quedó otro).
func despedir() -> void:
	if estado != Estado.FUERA:
		_irse()


func _atender_salida(_delta: float) -> bool:
	# Si cae a la calle mientras vende, ya no regresa: se va.
	if estado == Estado.VENDIENDO and not pasajeros.interior.esta_dentro(cuerpo):
		_irse()
	return false


func pensar(delta: float) -> void:
	match estado:
		Estado.SUBIENDO:
			if pasajeros.interior.esta_dentro(cuerpo):
				estado = Estado.VENDIENDO
				_paradas_restantes = azar.randi_range(int(roles.vendedor_paradas[0]), int(roles.vendedor_paradas[1]))
		Estado.VENDIENDO:
			if (_paradas_restantes <= 0 or vendedor.mercancia <= 0) and pasajeros.parada_actual >= 0 and pasajeros.interior.puerta_abierta:
				_bajar()
				return
			_vender(delta)
		Estado.BAJANDO:
			if not pasajeros.interior.esta_dentro(cuerpo):
				_irse()
		Estado.YENDOSE:
			var lejos := pasajeros.interior.camion.global_transform * (GestorPasajeros.PUERTA_AFUERA + Vector3(5.0, 0.0, 2.0))
			caminar_hacia(pasajeros.interior.camion.global_transform.affine_inverse() * lejos)
			if _tiempo > 3.0:
				_quitar()


func _vender(delta: float) -> void:
	var pendientes := pasajeros.a_bordo_que("sin_ofrecer")
	if _objetivo == null or not is_instance_valid(_objetivo) or not _objetivo in pendientes:
		_objetivo = null
		var aqui := pasajeros.interior.posicion_local(cuerpo)
		var mejor := INF
		for otro in pendientes:
			var d := aqui.distance_to(pasajeros.punto_para_atender(otro))
			if d < mejor:
				mejor = d
				_objetivo = otro
		_espera = roles.reaccion_bot
	if _objetivo == null:
		caminar_hacia(puesto)
		return
	if not caminar_hacia(pasajeros.punto_para_atender(_objetivo), 1.0, 0.6):
		return
	if voltear_hacia(_objetivo.global_position + Vector3.UP * _objetivo.altura * 0.6):
		_espera -= delta
		if _espera <= 0.0:
			cuerpo.comandos.accion_rol = true
			_espera = roles.reaccion_bot * 2.0


func _subir() -> void:
	_contador += 1
	cuerpo = nuevo_cuerpo("BotVendedor%d" % _contador, modelo)
	var interior := pasajeros.interior
	var afuera := interior.camion.global_transform * (GestorPasajeros.PUERTA_AFUERA + Vector3(1.0, 0.0, 0.5))
	interior.agregar_en_calle(cuerpo, null, Transform3D(Basis(), afuera + Vector3.UP * 0.05))
	cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
	cuerpo.atravesar_personajes(true)
	ragdolls.vigilar(cuerpo)
	vendedor.cuerpo = cuerpo
	vendedor.llenar_caja()
	subir_por_la_puerta()
	estado = Estado.SUBIENDO
	veces_subio += 1
	_tiempo = 0.0


func _bajar() -> void:
	por_recorrer = [Vector3(0.0, -0.3, -2.6), GestorPasajeros.PUERTA_ADENTRO, GestorPasajeros.PUERTA_UMBRAL, GestorPasajeros.PUERTA_AFUERA]
	estado = Estado.BAJANDO
	_tiempo = 0.0


func _irse() -> void:
	por_recorrer.clear()
	estado = Estado.YENDOSE
	_tiempo = 0.0


func _quitar() -> void:
	if vendedor.cuerpo == cuerpo:
		vendedor.cuerpo = null
	if cuerpo != null and is_instance_valid(cuerpo):
		pasajeros.interior.quitar(cuerpo)
		cuerpo.queue_free()
	cuerpo = null
	estado = Estado.FUERA


func _es_terminal(k: int) -> bool:
	return not pasajeros.pista.cerrada and k == pasajeros.pista.paradas.size() - 1
