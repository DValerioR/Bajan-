class_name ObjetoSuelto
extends RigidBody3D
## Objeto físico que se puede agarrar, lanzar y empujar (bolsas, monedas, el maniquí).
## Dentro del camión vive en el espacio del interior y recibe la gravedad y los empujones del
## camión desde su marco; en la calle usa la física normal.

const CAPA := 16
## Velocidad (m/s, respecto a quien recibe el golpe) a partir de la cual un objeto que pega
## a un personaje lo empuja. Lo pesado empuja más.
const VELOCIDAD_GOLPE := 3.0

var marco := MarcoMovimiento.new()
## Material físico (las monedas usan más fricción y nada de rebote para no rodar lejos).
var friccion: float = 0.8
var rebote: float = 0.15


func _ready() -> void:
	collision_layer = CAPA
	collision_mask = 1 | 4 | 8 | CAPA
	continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = friccion
	material.bounce = rebote
	physics_material_override = material
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_al_chocar)


## Para el interior del camión: el centro de su forma, sin importar hacia dónde esté volteado.
## (Con el "medio metro arriba del origen" de siempre, una moneda boca abajo parecía estar medio
## metro bajo el piso, el camión la daba por fuera y desaparecía.)
func centro() -> Vector3:
	for hijo in get_children():
		if hijo is CollisionShape3D:
			return (hijo as CollisionShape3D).global_position
	return global_position


## Algo que vuela (una bolsa, la pierna de otro pasajero) le pega a un personaje.
func _al_chocar(otro: Node) -> void:
	if not otro is CuerpoPersonaje:
		return
	var relativa: Vector3 = linear_velocity - (otro as CuerpoPersonaje).velocity
	if relativa.length() > VELOCIDAD_GOLPE:
		otro.empujar(relativa * minf(1.0, mass / 40.0))


func _physics_process(_delta: float) -> void:
	if marco is MarcoInterior:
		gravity_scale = 0.0
		apply_central_force(mass * (marco.gravedad(global_position) + marco.empuje(global_position)))
	else:
		gravity_scale = 1.0
