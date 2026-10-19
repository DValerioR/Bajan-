class_name Cobrador
extends Node
## Rol de cobrador (DISEÑO.md, sección 5.1; etapa 4) para un personaje (jugador o, más
## adelante, bot). Con la acción de cobrar le cobra al pasajero sin pagar que tiene enfrente.
## Lo cobrado va a su morral; en cada parada se entrega al fondo común (D39).
## "Las monedas caen al suelo si el camión frena o gira mal": al tropezar se le riega parte del
## morral y al caer como ragdoll todo, como monedas físicas que se recogen pasando sobre ellas.
## Las que salen a la calle se pierden.

signal cobro(monto: int)
signal se_rego(monto: int)
signal entrego(monto: int)
signal moneda_perdida(monto: int)

@export var cuerpo: CuerpoPersonaje
@export var pasajeros: GestorPasajeros
@export var ragdolls: GestorRagdolls

## Dinero cobrado que todavía no se entrega al fondo.
var morral: int = 0
## Totales para la interfaz y las pruebas.
var total_cobrado: int = 0
var total_regado: int = 0
var total_perdido: int = 0

var _monedas: Array[Dictionary] = []
var _tropezaba: bool = false
var _parada_anterior: int = -1


func _ready() -> void:
	ragdolls.desplomado.connect(func(quien):
		if quien == cuerpo:
			_regar(morral))


func _physics_process(delta: float) -> void:
	# Sin cuerpo: el rol va de una persona a otra (rotación de "Tírame paro").
	if cuerpo == null or not is_instance_valid(cuerpo):
		return
	var p := Juego.parametros
	var c := cuerpo.comandos
	if c.accion_rol:
		c.accion_rol = false
		_intentar_cobrar(p)

	# Tropezar riega parte del morral.
	var tropieza := cuerpo.tropezando > 0.0 and not cuerpo.desplomado
	if tropieza and not _tropezaba:
		_regar(roundi(morral * p.derrame_tropiezo))
	_tropezaba = tropieza

	# Al llegar a cada parada, lo del morral pasa al fondo.
	var parada := pasajeros.parada_actual
	if parada >= 0 and parada != _parada_anterior and morral > 0 and not cuerpo.desplomado:
		Juego.ingresar(morral)
		entrego.emit(morral)
		morral = 0
	_parada_anterior = parada

	_atender_monedas(delta, p)


func _intentar_cobrar(p: ParametrosPartida) -> void:
	if cuerpo.desplomado or not pasajeros.interior.esta_dentro(cuerpo):
		return
	var desde := cuerpo.cabeza.global_position
	var mirada := -cuerpo.cabeza.global_basis.z
	var pasajero := pasajeros.por_cobrar_cerca(desde, mirada, p.alcance_cobro)
	if pasajero == null:
		return
	var monto := pasajeros.cobrar(pasajero)
	if monto > 0:
		morral += monto
		total_cobrado += monto
		cobro.emit(monto)


## Riega `monto` del morral como monedas físicas alrededor del cobrador.
func _regar(monto: int) -> void:
	var p := Juego.parametros
	monto = mini(monto, morral)
	if monto <= 0:
		return
	morral -= monto
	total_regado += monto
	se_rego.emit(monto)
	var cuantas := clampi(ceili(float(monto) / p.valor_moneda), 1, p.max_monedas)
	var interior := pasajeros.interior
	var dentro := interior.esta_dentro(cuerpo)
	var restante := monto
	for k in cuantas:
		var valor := restante if k == cuantas - 1 else mini(restante, ceili(float(monto) / cuantas))
		restante -= valor
		var moneda := _crear_moneda()
		var donde := cuerpo.global_transform * Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3))
		var lados := p.velocidad_regado
		var velocidad := Vector3(randf_range(-lados, lados), randf_range(0.5, 1.5), randf_range(-lados, lados)) + cuerpo.velocity
		if dentro:
			interior.agregar(moneda, null, Transform3D(Basis(), donde))
		else:
			interior.agregar_en_calle(moneda, null, Transform3D(Basis(), donde))
		moneda.linear_velocity = velocidad
		_monedas.append({"moneda": moneda, "valor": valor, "en_calle": 0.0})


func _crear_moneda() -> ObjetoSuelto:
	var moneda := ObjetoSuelto.new()
	moneda.name = "Moneda"
	moneda.mass = 0.05
	# Que caigan y se queden: si ruedan de canto, se salen por la puerta.
	moneda.friccion = 1.0
	moneda.rebote = 0.0
	moneda.angular_damp = 6.0
	moneda.linear_damp = 1.5
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = 0.06
	cilindro.height = 0.03
	forma.shape = cilindro
	moneda.add_child(forma)
	var visual := Node3D.new()
	visual.name = "Visual"
	var malla := MeshInstance3D.new()
	var dibujo := CylinderMesh.new()
	dibujo.top_radius = 0.06
	dibujo.bottom_radius = 0.06
	dibujo.height = 0.03
	dibujo.radial_segments = 10
	malla.mesh = dibujo
	malla.material_override = EstiloToon.material(Color(1.0, 0.8, 0.22), true)
	visual.add_child(malla)
	moneda.add_child(visual)
	return moneda


## Recoge las monedas cercanas (en el mismo espacio) y pierde las que llevan rato en la calle.
func _atender_monedas(delta: float, p: ParametrosPartida) -> void:
	var interior := pasajeros.interior
	for datos in _monedas.duplicate():
		# Se revisa antes de asignar con tipo: asignar una instancia ya liberada es un error.
		if not is_instance_valid(datos.moneda):
			_monedas.erase(datos)
			continue
		var moneda: ObjetoSuelto = datos.moneda
		if not interior.esta_dentro(moneda):
			datos.en_calle += delta
			if datos.en_calle > p.vida_moneda_en_calle:
				total_perdido += datos.valor
				moneda_perdida.emit(datos.valor)
				_quitar(datos)
			continue
		datos.en_calle = 0.0
		var mismo_espacio := interior.esta_dentro(cuerpo) and not cuerpo.desplomado
		if mismo_espacio and moneda.global_position.distance_to(cuerpo.global_position + Vector3.UP * 0.3) < p.alcance_moneda:
			morral += datos.valor
			_quitar(datos)


func _quitar(datos: Dictionary) -> void:
	pasajeros.interior.quitar(datos.moneda)
	datos.moneda.queue_free()
	_monedas.erase(datos)


func monedas_en_el_piso() -> int:
	return _monedas.size()
