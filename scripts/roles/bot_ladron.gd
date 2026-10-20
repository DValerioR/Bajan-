class_name BotLadron
extends BotInterior
## El ratero del evento de robo: sube en una parada, sigue al que trae el morral del cobrador
## (jugador o bot) y, si lo alcanza con dinero, se lo roba y se va a la puerta para bajarse en la
## siguiente parada. Si lo tumban antes (un empujón, un frenazo), se le cae el botín en monedas que
## cualquiera puede recoger. Si se baja con el botín, ese dinero se pierde.
## Usa el mismo cuerpo y la misma física que cualquiera. Mientras busca al cobrador no se sujeta
## (un frenazo lo tumba); ya con el botín espera en la puerta agarrado del poste, y solo uno fuerte,
## si no alcanza a reaccionar, lo tira.

signal robo(monto: int)
signal se_le_cayo(monto: int)
signal se_fue(monto: int)

enum Estado { SUBIENDO, ACECHANDO, HUYENDO, BAJANDO, YENDOSE }

@export var ragdolls: GestorRagdolls
@export var cobrador: Cobrador
## Distancia (m) a la que alcanza a meterle la mano al morral.
var alcance: float = 0.9
## Parada donde se subió (se baja en otra).
var parada_subida: int = -1

var estado: Estado = Estado.SUBIENDO
var botin: int = 0
var _tiempo: float = 0.0


func _ready() -> void:
	super._ready()
	ragdolls.desplomado.connect(_al_desplomarse)


func _physics_process(delta: float) -> void:
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	_tiempo += delta
	match estado:
		Estado.SUBIENDO:
			# Si el camión se fue antes de que subiera, se va.
			if _tiempo > 15.0 and not pasajeros.interior.esta_dentro(cuerpo):
				_irse()
			elif por_recorrer.is_empty() and pasajeros.interior.esta_dentro(cuerpo):
				estado = Estado.ACECHANDO
		Estado.BAJANDO:
			if not pasajeros.interior.esta_dentro(cuerpo) or _tiempo > 12.0:
				_irse()
		Estado.YENDOSE:
			if _tiempo > 3.0:
				_quitar()
				return
	super._physics_process(delta)


func pensar(_delta: float) -> void:
	match estado:
		Estado.ACECHANDO:
			if _toca_bajarse():
				_bajar()
				return
			var victima := cobrador.cuerpo if cobrador != null else null
			if victima == null or not is_instance_valid(victima) or victima.desplomado or not pasajeros.interior.esta_dentro(victima):
				caminar_hacia(Vector3(0.0, -0.28, 0.5))
				return
			var donde := pasajeros.interior.posicion_local(victima)
			if caminar_hacia(donde, 1.15, alcance) and cobrador.morral > 0:
				botin = cobrador.morral
				cobrador.morral = 0
				estado = Estado.HUYENDO
				robo.emit(botin)
		Estado.HUYENDO:
			# Junto a la puerta, esperando la siguiente parada para bajarse.
			if _toca_bajarse():
				_bajar()
			else:
				caminar_hacia(GestorPasajeros.PUERTA_ADENTRO + Vector3(0.3, 0.0, 0.5))
		Estado.YENDOSE:
			var lejos := pasajeros.interior.camion.global_transform * (GestorPasajeros.PUERTA_AFUERA + Vector3(6.0, 0.0, 3.0))
			caminar_hacia(pasajeros.interior.camion.global_transform.affine_inverse() * lejos, 1.3)


func quiere_sujetarse() -> bool:
	return estado == Estado.HUYENDO


func _toca_bajarse() -> bool:
	var parada := pasajeros.parada_actual
	return parada >= 0 and parada != parada_subida and pasajeros.interior.puerta_abierta


func _atender_salida(_delta: float) -> bool:
	# Fuera del camión no vuelve a subir: se va (con lo que traiga).
	if estado in [Estado.ACECHANDO, Estado.HUYENDO] and not pasajeros.interior.esta_dentro(cuerpo) and not cuerpo.desplomado:
		_irse()
	return false


func _bajar() -> void:
	por_recorrer = [GestorPasajeros.PUERTA_ADENTRO, GestorPasajeros.PUERTA_UMBRAL, GestorPasajeros.PUERTA_AFUERA]
	estado = Estado.BAJANDO
	_tiempo = 0.0


func _irse() -> void:
	por_recorrer.clear()
	estado = Estado.YENDOSE
	_tiempo = 0.0


func _quitar() -> void:
	se_fue.emit(botin)
	if cuerpo != null and is_instance_valid(cuerpo):
		pasajeros.interior.quitar(cuerpo)
		cuerpo.queue_free()
	cuerpo = null
	queue_free()


## Lo tumbaron: se le cae el botín y, al levantarse, ya solo quiere huir.
func _al_desplomarse(quien: CuerpoPersonaje) -> void:
	if quien != cuerpo:
		return
	if botin > 0 and cobrador != null:
		cobrador.regar_botin(botin, cuerpo)
		se_le_cayo.emit(botin)
		botin = 0
	if estado == Estado.ACECHANDO:
		estado = Estado.HUYENDO
