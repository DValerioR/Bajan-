class_name BotVendedor
extends BotInterior
## Bot vendedor (etapa 6A): no viaja siempre a bordo (DISEÑO.md, sección 5.1). En algunas paradas
## sube con la caja llena, recorre el pasillo ofreciendo dulces (con el nodo Vendedor, igual que un
## jugador) y unas paradas después, o al acabarse la mercancía, se baja y se va.
## Mientras no viene a bordo no tiene cuerpo: este nodo lo crea al subir y lo quita al irse.

enum Estado { FUERA, SUBIENDO, VENDIENDO, BAJANDO, YENDOSE }

@export var ragdolls: GestorRagdolls
## Modelo de personaje del vendedor.
var modelo: String = "vendedora"

var estado: Estado = Estado.FUERA
var vendedor: Vendedor
## Totales de todas sus vueltas (para la interfaz y las pruebas).
var veces_subio: int = 0
var total_ventas: int = 0
var total_propinas: int = 0

var _ruta: Array[Vector3] = []
var _paradas_restantes: int = 0
var _parada_anterior: int = -1
var _objetivo: CuerpoPersonaje
var _espera: float = 0.0
var _tiempo: float = 0.0
var _contador: int = 0


func _physics_process(delta: float) -> void:
	var parada := pasajeros.parada_actual
	var llego := parada >= 0 and parada != _parada_anterior
	_parada_anterior = parada
	if estado == Estado.FUERA:
		if llego and pasajeros.interior.puerta_abierta and not _es_terminal(parada) and azar.randf() < roles.vendedor_sube:
			_subir()
		return
	if llego:
		_paradas_restantes -= 1
	super._physics_process(delta)


func _atender_salida(delta: float) -> bool:
	# Si cae a la calle mientras vende, ya no regresa: se va.
	if estado == Estado.VENDIENDO and not pasajeros.interior.esta_dentro(cuerpo):
		_irse()
	return false


func pensar(delta: float) -> void:
	_tiempo += delta
	match estado:
		Estado.SUBIENDO:
			if pasajeros.interior.esta_dentro(cuerpo) and _ruta.size() <= 1:
				estado = Estado.VENDIENDO
				_paradas_restantes = azar.randi_range(int(roles.vendedor_paradas[0]), int(roles.vendedor_paradas[1]))
			elif _seguir_ruta() or _tiempo > 15.0:
				# No alcanzó a subir (el camión se fue): se va.
				if not pasajeros.interior.esta_dentro(cuerpo):
					_irse()
		Estado.VENDIENDO:
			if (_paradas_restantes <= 0 or vendedor.mercancia <= 0) and pasajeros.parada_actual >= 0 and pasajeros.interior.puerta_abierta:
				_bajar()
				return
			_vender(delta)
		Estado.BAJANDO:
			if not pasajeros.interior.esta_dentro(cuerpo) or _seguir_ruta() or _tiempo > 12.0:
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


func _seguir_ruta() -> bool:
	while not _ruta.is_empty():
		if not caminar_hacia(_ruta[0], 1.0, 0.4):
			return false
		_ruta.remove_at(0)
	return true


func _subir() -> void:
	_contador += 1
	cuerpo = nuevo_cuerpo("BotVendedor%d" % _contador, modelo)
	var interior := pasajeros.interior
	var afuera := interior.camion.global_transform * (GestorPasajeros.PUERTA_AFUERA + Vector3(1.0, 0.0, 0.5))
	interior.agregar_en_calle(cuerpo, null, Transform3D(Basis(), afuera + Vector3.UP * 0.05))
	cuerpo.configurar(cuerpo.visual.altura, cuerpo.visual.altura_ojos)
	cuerpo.atravesar_personajes(true)
	ragdolls.vigilar(cuerpo)
	vendedor = Vendedor.new()
	vendedor.name = "Vendedor"
	vendedor.cuerpo = cuerpo
	vendedor.pasajeros = pasajeros
	vendedor.ragdolls = ragdolls
	add_child(vendedor)
	vendedor.vendio.connect(func(monto):
		total_ventas += 1
		total_propinas += monto)
	_ruta = [GestorPasajeros.PUERTA_AFUERA, GestorPasajeros.PUERTA_UMBRAL, GestorPasajeros.PUERTA_ADENTRO, puesto]
	estado = Estado.SUBIENDO
	veces_subio += 1
	_tiempo = 0.0


func _bajar() -> void:
	_ruta = [Vector3(0.0, -0.3, -2.6), GestorPasajeros.PUERTA_ADENTRO, GestorPasajeros.PUERTA_UMBRAL, GestorPasajeros.PUERTA_AFUERA]
	estado = Estado.BAJANDO
	_tiempo = 0.0


func _irse() -> void:
	estado = Estado.YENDOSE
	_tiempo = 0.0


func _quitar() -> void:
	if vendedor != null:
		vendedor.queue_free()
		vendedor = null
	if cuerpo != null and is_instance_valid(cuerpo):
		pasajeros.interior.quitar(cuerpo)
		cuerpo.queue_free()
	cuerpo = null
	estado = Estado.FUERA


func _es_terminal(k: int) -> bool:
	return not pasajeros.pista.cerrada and k == pasajeros.pista.paradas.size() - 1
