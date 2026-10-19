class_name BotCobrador
extends BotInterior
## Bot cobrador (etapa 6A): va con el pasajero sin pagar más cercano, se para frente a él y le
## cobra (con el nodo Cobrador, igual que un jugador). Si no hay a quién cobrar, espera a la mitad
## del pasillo. Lo del morral y las monedas regadas lo hace el Cobrador.

var _objetivo: CuerpoPersonaje
var _espera: float = 0.0


func pensar(delta: float) -> void:
	if _objetivo == null or not is_instance_valid(_objetivo) or not _objetivo in pasajeros.a_bordo_que("sin_pagar"):
		_objetivo = _mas_cercano()
		_espera = roles.reaccion_bot
	if _objetivo == null:
		caminar_hacia(puesto)
		return
	var punto := pasajeros.punto_para_atender(_objetivo)
	if not caminar_hacia(punto, 1.0, 0.6):
		return
	# Ya está junto: voltea, se toma su tiempo y cobra.
	if voltear_hacia(_objetivo.global_position + Vector3.UP * _objetivo.altura * 0.6):
		_espera -= delta
		if _espera <= 0.0:
			cuerpo.comandos.accion_rol = true
			_espera = roles.reaccion_bot


func _mas_cercano() -> CuerpoPersonaje:
	var aqui := pasajeros.interior.posicion_local(cuerpo)
	var mejor: CuerpoPersonaje = null
	var mejor_distancia := INF
	for otro in pasajeros.a_bordo_que("sin_pagar"):
		var d := aqui.distance_to(pasajeros.punto_para_atender(otro))
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = otro
	return mejor
