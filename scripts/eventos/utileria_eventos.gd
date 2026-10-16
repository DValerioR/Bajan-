class_name UtileriaEventos
extends RefCounted
## Lo que se ve (y estorba) en los eventos, hecho con formas básicas: animales cruzando, la valla
## de una obra, la lluvia y el inspector. Se sustituirá por modelos en la etapa 7.

const CAPA_CALLE := 1


## Una vaca y tres gallinas que cruzan la calle de derecha a izquierda. La vaca estorba (sólida);
## las gallinas solo se ven. Devuelve un AnimatableBody3D que GestorEventos mueve.
static func animales() -> AnimatableBody3D:
	var grupo := AnimatableBody3D.new()
	grupo.name = "Animales"
	grupo.collision_layer = CAPA_CALLE
	grupo.collision_mask = 0
	var blanco := Color(0.95, 0.93, 0.88)
	var negro := Color(0.12, 0.1, 0.1)
	var rosa := Color(0.95, 0.6, 0.6)
	# Vaca: cuerpo, cabeza, patas y manchas. Mira hacia donde camina (-X local).
	_caja(grupo, Vector3(1.6, 0.8, 0.7), Vector3(0, 1.05, 0), blanco)
	_caja(grupo, Vector3(0.5, 0.45, 0.4), Vector3(-1.0, 1.35, 0), blanco)
	_caja(grupo, Vector3(0.2, 0.18, 0.32), Vector3(-1.28, 1.25, 0), rosa)
	_caja(grupo, Vector3(0.45, 0.35, 0.05), Vector3(0.2, 1.2, 0.36), negro)
	_caja(grupo, Vector3(0.35, 0.3, 0.05), Vector3(-0.4, 0.95, -0.36), negro)
	for x in [-0.6, 0.6]:
		for z in [-0.22, 0.22]:
			_caja(grupo, Vector3(0.15, 0.65, 0.15), Vector3(x, 0.33, z), blanco)
	_caja(grupo, Vector3(0.08, 0.15, 0.08), Vector3(-1.05, 1.66, 0.14), Color(0.9, 0.85, 0.6))
	_caja(grupo, Vector3(0.08, 0.15, 0.08), Vector3(-1.05, 1.66, -0.14), Color(0.9, 0.85, 0.6))
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(2.4, 1.6, 0.8)
	forma.shape = caja
	forma.position = Vector3(-0.2, 0.85, 0)
	grupo.add_child(forma)
	# Gallinas: atrás de la vaca, en fila.
	for k in 3:
		var base := Vector3(1.4 + 0.6 * k, 0, 0.5 - 0.5 * k)
		_caja(grupo, Vector3(0.3, 0.25, 0.22), base + Vector3(0, 0.3, 0), Color(0.85, 0.45, 0.2))
		_caja(grupo, Vector3(0.12, 0.14, 0.12), base + Vector3(-0.18, 0.5, 0), Color(0.85, 0.45, 0.2))
		_caja(grupo, Vector3(0.08, 0.08, 0.04), base + Vector3(-0.18, 0.62, 0), Color(0.9, 0.15, 0.1))
		_caja(grupo, Vector3(0.04, 0.18, 0.04), base + Vector3(0, 0.09, 0), Color(0.95, 0.8, 0.2))
	EstiloToon.aplicar(grupo)
	return grupo


## Valla de obra a lo ancho de la calle con conos y letrero. Sólida.
static func valla(ancho: float) -> StaticBody3D:
	var valla := StaticBody3D.new()
	valla.name = "Valla"
	valla.collision_layer = CAPA_CALLE
	valla.collision_mask = 0
	var naranja := Color(1.0, 0.5, 0.1)
	var blanco := Color(0.97, 0.97, 0.95)
	var franjas := int(ancho / 0.8)
	for k in franjas:
		var x := -ancho * 0.5 + 0.4 + k * 0.8
		_caja(valla, Vector3(0.8, 0.3, 0.08), Vector3(x, 0.9, 0), naranja if k % 2 == 0 else blanco)
	for x in [-ancho * 0.5 + 0.1, 0.0, ancho * 0.5 - 0.1]:
		_caja(valla, Vector3(0.08, 1.05, 0.08), Vector3(x, 0.52, 0), Color(0.3, 0.3, 0.32))
	# Conos del lado por donde llega el camión (+Z local).
	for k in 6:
		var cono := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = 0.03
		malla.bottom_radius = 0.2
		malla.height = 0.6
		malla.radial_segments = 10
		malla.material = _material(naranja)
		cono.mesh = malla
		cono.position = Vector3(-ancho * 0.5 + (k + 0.5) * ancho / 6.0, 0.3, 1.2)
		valla.add_child(cono)
	var letrero := Label3D.new()
	letrero.text = "LETRERO_OBRA"
	letrero.font_size = 48
	letrero.pixel_size = 0.006
	letrero.outline_size = 12
	letrero.modulate = Color(1, 0.9, 0.3)
	letrero.outline_modulate = Color(0.1, 0.08, 0.06)
	letrero.position = Vector3(0, 1.45, 0)
	letrero.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	valla.add_child(letrero)
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ancho, 1.1, 0.3)
	forma.shape = caja
	forma.position = Vector3(0, 0.55, 0)
	valla.add_child(forma)
	EstiloToon.aplicar(valla)
	return valla


## Lluvia: gotas alargadas que caen en una caja alrededor de lo que siga (la cámara o el camión).
static func lluvia() -> CPUParticles3D:
	var gotas := CPUParticles3D.new()
	gotas.name = "Lluvia"
	gotas.amount = 900
	gotas.lifetime = 0.9
	gotas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	gotas.emission_box_extents = Vector3(14, 0.5, 18)
	gotas.direction = Vector3(0.1, -1, 0)
	gotas.spread = 3.0
	gotas.initial_velocity_min = 16.0
	gotas.initial_velocity_max = 20.0
	gotas.gravity = Vector3(0, -9.8, 0)
	gotas.local_coords = false
	var malla := BoxMesh.new()
	malla.size = Vector3(0.02, 0.5, 0.02)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.82, 0.95, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	malla.material = material
	gotas.mesh = malla
	gotas.position = Vector3(0, 9, 0)
	return gotas


## El inspector: un personaje parado en la parada con su letrero encima.
static func inspector() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Inspector"
	var figura := Personaje.new()
	figura.name = "Figura"
	figura.modelo = "oficinista"
	raiz.add_child(figura)
	var letrero := Label3D.new()
	letrero.text = "LETRERO_INSPECTOR"
	letrero.font_size = 56
	letrero.pixel_size = 0.006
	letrero.outline_size = 14
	letrero.modulate = Color(1.0, 0.35, 0.3)
	letrero.outline_modulate = Color(0.1, 0.06, 0.06)
	letrero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letrero.position = Vector3(0, 2.3, 0)
	raiz.add_child(letrero)
	return raiz


static func _caja(padre: Node3D, medidas: Vector3, posicion: Vector3, color: Color) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = medidas
	caja.material = _material(color)
	malla.mesh = caja
	malla.position = posicion
	padre.add_child(malla)
	return malla


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
