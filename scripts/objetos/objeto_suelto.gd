class_name ObjetoSuelto
extends RigidBody3D
## Objeto físico que se puede agarrar, lanzar y empujar (bolsas, monedas, el maniquí).
## Dentro del camión vive en el espacio del interior y recibe la gravedad y los empujones del
## camión desde su marco; en la calle usa la física normal.

const CAPA := 16

var marco := MarcoMovimiento.new()


func _ready() -> void:
	collision_layer = CAPA
	collision_mask = 1 | 4 | 8 | CAPA
	continuous_cd = true
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.15
	physics_material_override = material


func _physics_process(_delta: float) -> void:
	if marco is MarcoInterior:
		gravity_scale = 0.0
		apply_central_force(mass * (marco.gravedad(global_position) + marco.empuje(global_position)))
	else:
		gravity_scale = 1.0
