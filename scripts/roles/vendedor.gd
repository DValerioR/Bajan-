class_name Vendedor
extends Node
## Rol de vendedor de dulces (DISEÑO.md, sección 5.1; etapa 6A) para un personaje (jugador o bot).
## Con la acción del rol le ofrece dulce al pasajero que tiene enfrente (a cada uno una vez); si
## quiere, deja propina, que entra directo al fondo. La mercancía es limitada: se le caen dulces al
## tropezar o caer, y se repone gratis en los puestos de dulces de algunas paradas, bajándose un
## momento hasta el puesto.

signal vendio(monto: int)
signal no_quiso
signal se_le_cayeron(cuantos: int)
signal reabastecio

@export var cuerpo: CuerpoPersonaje
@export var pasajeros: GestorPasajeros
@export var ragdolls: GestorRagdolls

## Puestos de dulces, en coordenadas del mundo.
var puestos: Array[Vector3] = []
var mercancia: int = 0
## Totales para la interfaz y las pruebas.
var total_propinas: int = 0
var total_ventas: int = 0
var total_caidos: int = 0
var total_reabastecidas: int = 0

var _roles: ParametrosRoles
var _tropezaba: bool = false


func _ready() -> void:
	_roles = ParametrosRoles.cargar()
	Config.recargado.connect(func(): _roles = ParametrosRoles.cargar())
	mercancia = _roles.mercancia
	ragdolls.desplomado.connect(func(quien):
		if quien == cuerpo:
			_tirar(_roles.perdida_caida))


func _physics_process(_delta: float) -> void:
	var c := cuerpo.comandos
	if c.accion_rol:
		c.accion_rol = false
		_intentar_vender()

	# Con los frenazos se le caen dulces.
	var tropieza := cuerpo.tropezando > 0.0 and not cuerpo.desplomado
	if tropieza and not _tropezaba:
		_tirar(_roles.perdida_tropiezo)
	_tropezaba = tropieza

	if mercancia < _roles.mercancia and puesto_cerca():
		mercancia = _roles.mercancia
		total_reabastecidas += 1
		reabastecio.emit()


func _intentar_vender() -> void:
	if mercancia <= 0 or cuerpo.desplomado or not pasajeros.interior.esta_dentro(cuerpo):
		return
	var pasajero := pasajeros.por_vender_cerca(cuerpo.cabeza.global_position, -cuerpo.cabeza.global_basis.z, _roles.alcance_venta)
	if pasajero == null:
		return
	var propina := pasajeros.vender(pasajero)
	if propina <= 0:
		no_quiso.emit()
		return
	mercancia -= 1
	total_ventas += 1
	total_propinas += propina
	Juego.ingresar(propina)
	vendio.emit(propina)


func _tirar(cuantos: int) -> void:
	cuantos = mini(cuantos, mercancia)
	if cuantos <= 0:
		return
	mercancia -= cuantos
	total_caidos += cuantos
	se_le_cayeron.emit(cuantos)


## Si está en la calle, junto a un puesto de dulces.
func puesto_cerca() -> bool:
	if cuerpo.desplomado or pasajeros.interior.esta_dentro(cuerpo):
		return false
	for puesto in puestos:
		var d := puesto - cuerpo.global_position
		d.y = 0.0
		if d.length() < _roles.alcance_puesto:
			return true
	return false
