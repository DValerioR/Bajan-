class_name BotVoceador
extends BotInterior
## Bot voceador (etapa 6A): va en la puerta sujeto del poste. Cerca de una parada grita (por
## teclado, como cualquier voceador bot) a ratos, dejando que se le recupere el aliento, y en la
## parada jala a la gente que espera para que suba. Con el camión andando y alguien haciendo la
## parada a medio camino, se cuelga de la puerta y lo jala al pasar (D55).

@export var voceador: Voceador

var _gritando: bool = false
var _para_ayudar: float = 0.0
var _para_colgarse: float = 0.0


func pensar(delta: float) -> void:
	var colgado := cuerpo.colgado
	var en_puerta := colgado or caminar_hacia(puesto, 1.0, 0.3)
	if en_puerta and not colgado:
		voltear_hacia(pasajeros.interior.desde_local(cuerpo, GestorPasajeros.PUERTA_AFUERA))
	# Se cuelga si hay alguien adelante a medio camino; se mete al acercarse a la parada.
	var orilla := pasajeros.orilla_adelante()
	var quiere := pasajeros.interior.puerta_abierta and pasajeros.parada_actual < 0 and orilla < 70.0
	_para_colgarse -= delta
	if quiere != colgado and (colgado or voceador.puede_colgarse()) and _para_colgarse <= 0.0:
		cuerpo.comandos.sentarse = true
		_para_colgarse = roles.reaccion_bot * 2.0
	# Grita a ratos: hasta quedarse casi sin aire, y vuelve cuando ya recuperó.
	if pasajeros.parada_que_oye() >= 0:
		if _gritando and voceador.aliento < 8.0:
			_gritando = false
		elif not _gritando and voceador.aliento > 60.0:
			_gritando = true
	else:
		_gritando = false
	cuerpo.comandos.gritar = _gritando
	# En la parada, jala a uno cada tanto; colgado, al que va pasando.
	_para_ayudar -= delta
	if en_puerta and pasajeros.parada_actual >= 0 and _para_ayudar <= 0.0:
		cuerpo.comandos.accion_rol = true
		_para_ayudar = roles.reaccion_bot * 2.5
	elif colgado and absf(orilla + Voceador.MANO_AFUERA.z) < 0.8 and _para_ayudar <= 0.0:
		# Con el camión en marcha: estira la mano justo cuando lo va pasando.
		cuerpo.comandos.accion_rol = true
		_para_ayudar = 0.5


func quiere_sujetarse() -> bool:
	# En la puerta va agarrado del poste.
	return pasajeros.interior.posicion_local(cuerpo).distance_to(puesto) < 0.6
