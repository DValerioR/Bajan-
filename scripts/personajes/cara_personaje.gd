class_name CaraPersonaje
extends RefCounted
## Cara animada de un personaje de muñeco: párpados que parpadean y boca que se abre al hablar o
## gritar. La boca son dos claves de forma de la cabeza ("Cerrar" y "Abrir") que pone Blender
## (scripts/herramientas/caras_blender.py) a partir de `boca` en modelos/personajes.cfg. Los
## párpados se arman aquí al cargar, con `ojos`:
##   ojos = [[x, y, radio], ...]  centro de cada ojo (m, coordenadas de la figura, pies en 0)
##   cara_giro = grados hacia donde ve la cara (0 = al frente), para los de cabeza volteada.
## La cabeza se dibuja también por dentro, en oscuro: al abrirse la boca se ve su interior.
## Los párpados son una esfera del color de la piel sobre cada globo ocular, un poco más grande que
## el ojo, que el material va mostrando de arriba hacia abajo (como en las caricaturas).

const CONFIG := "res://modelos/personajes.cfg"
const SHADER_CABEZA := preload("res://materiales/toon_cabeza.gdshader")
const SHADER_PARPADO := preload("res://materiales/parpado.gdshader")
## Tamaño del párpado respecto al radio del ojo, y qué tanto sobresale de la punta del ojo
## (fracción de su radio).
const TAMANO_PARPADO := 1.08
const SOBRESALE_PARPADO := 0.25

## Lo ya armado por modelo (las mallas se comparten entre todos los que usan el modelo).
static var _hechas: Dictionary = {}


## Arma la cara sobre la pieza de la cabeza (ya con su material toon). Devuelve {} si el modelo no
## tiene cara animada, o {cabeza: MeshInstance3D o null (si no hay boca), cerrar: índice de la
## clave, abrir: índice, parpados: [ShaderMaterial]}.
static func armar(modelo: String, cabeza: MeshInstance3D) -> Dictionary:
	if cabeza == null or cabeza.mesh == null:
		return {}
	var cfg := Config.archivo_config(CONFIG)
	var malla := cabeza.mesh
	var cerrar := -1
	var abrir := -1
	for b in malla.get_blend_shape_count():
		match String(malla.get_blend_shape_name(b)):
			"Cerrar":
				cerrar = b
			"Abrir":
				abrir = b
	var con_boca := cerrar >= 0 and abrir >= 0
	if not con_boca and not cfg.has_section_key(modelo, "ojos"):
		return {}
	var resultado := {"cabeza": cabeza if con_boca else null, "cerrar": cerrar, "abrir": abrir, "parpados": []}
	if not _hechas.has(modelo):
		_hechas[modelo] = _preparar(modelo, cabeza, cfg)
	var hecha: Dictionary = _hechas[modelo]
	if con_boca:
		cabeza.set_surface_override_material(0, _material_cabeza(cabeza.get_active_material(0) as ShaderMaterial))
		cabeza.set_blend_shape_value(cerrar, 1.0)
	for datos in hecha.get("parpados", []):
		var parpado := MeshInstance3D.new()
		parpado.name = "Parpado"
		parpado.mesh = datos.malla
		var material := ShaderMaterial.new()
		material.shader = SHADER_PARPADO
		material.set_shader_parameter("color_piel", datos.color)
		material.set_shader_parameter("tope", datos.tope)
		material.set_shader_parameter("fondo", datos.fondo)
		material.set_shader_parameter("linea", (datos.tope + datos.fondo) * 0.5 - (datos.tope - datos.fondo) * 0.05)
		parpado.material_override = material
		parpado.set_meta("sin_contorno", true)
		cabeza.add_child(parpado)
		resultado.parpados.append(material)
	return resultado


## La misma apariencia que el toon de la cabeza, pero también por dentro (oscuro).
static func _material_cabeza(toon: ShaderMaterial) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER_CABEZA
	if toon != null:
		for parametro in ["color_base", "textura", "usar_textura"]:
			material.set_shader_parameter(parametro, toon.get_shader_parameter(parametro))
		material.next_pass = toon.next_pass
	return material


static func _preparar(modelo: String, cabeza: MeshInstance3D, cfg: ConfigFile) -> Dictionary:
	var hecha := {}
	var malla := cabeza.mesh
	var arreglos: Array = malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arreglos[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(vertices.size())
		for i in vertices.size():
			indices[i] = i
	var origen := cabeza.position
	var giro := deg_to_rad(float(cfg.get_value(modelo, "cara_giro", 0.0)))
	# Hacia dónde ve la cara (en el plano del piso; el frente de la figura es -Z).
	var frente := Vector3(-sin(giro), 0.0, -cos(giro))
	var adelante := func(p: Vector3) -> float: return p.x * frente.x + p.z * frente.z

	if cfg.has_section_key(modelo, "ojos"):
		var imagen := _imagen_de(cabeza)
		var uvs: PackedVector2Array = arreglos[Mesh.ARRAY_TEX_UV]
		var parpados := []
		var color_piel := _color_de_piel(imagen, vertices, uvs, indices, origen, cfg.get_value(modelo, "ojos"))
		for ojo in cfg.get_value(modelo, "ojos"):
			var centro := Vector3(float(ojo[0]), float(ojo[1]), 0.0)
			var radio := float(ojo[2])
			# La punta del ojo: lo más adelantado (hacia donde ve la cara) cerca de su centro.
			var punta := Vector3.INF
			var mas_adelante := -INF
			for v in vertices:
				var p := origen + v
				if Vector2(p.x - centro.x, p.y - centro.y).length() < radio * 0.5 and adelante.call(p) > mas_adelante:
					mas_adelante = adelante.call(p)
					punta = p
			if punta == Vector3.INF:
				continue
			var tamano := radio * TAMANO_PARPADO
			var centro_esfera := punta - frente * tamano * (1.0 - SOBRESALE_PARPADO) - origen
			parpados.append({
				"malla": _malla_parpado(centro_esfera, tamano),
				"color": color_piel,
				"tope": centro_esfera.y + tamano,
				"fondo": centro_esfera.y - tamano,
			})
		hecha.parpados = parpados
	return hecha


static func _malla_parpado(centro: Vector3, radio: float) -> ArrayMesh:
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 20
	esfera.rings = 12
	var datos := esfera.get_mesh_arrays()
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] += centro
	datos[Mesh.ARRAY_VERTEX] = vertices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	return malla


## Color de la piel alrededor de los ojos, para los párpados (el mismo para los dos): la mediana
## de cada canal en un anillo alrededor de cada ojo, sin lo oscuro (cejas, pelo, pestañas) ni lo
## blanco (el ojo). La mediana no se deja jalar por el rubor de las mejillas.
static func _color_de_piel(imagen: Image, vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, origen: Vector3, ojos: Array) -> Color:
	var rojos := PackedFloat32Array()
	var verdes := PackedFloat32Array()
	var azules := PackedFloat32Array()
	if imagen != null and not uvs.is_empty():
		for i in indices:
			var p := origen + vertices[i]
			for ojo in ojos:
				var radio := float(ojo[2])
				var d := Vector2(p.x - float(ojo[0]), p.y - float(ojo[1])).length()
				if d < radio * 1.15 or d > radio * 1.6:
					continue
				var uv := uvs[i]
				var px := clampi(int(uv.x * imagen.get_width()), 0, imagen.get_width() - 1)
				var py := clampi(int(uv.y * imagen.get_height()), 0, imagen.get_height() - 1)
				var color := imagen.get_pixel(px, py)
				if color.get_luminance() > 0.3 and color.get_luminance() < 0.92 and color.r > color.b + 0.08:
					rojos.append(color.r)
					verdes.append(color.g)
					azules.append(color.b)
	if rojos.is_empty():
		return Color(0.93, 0.6, 0.42)
	rojos.sort()
	verdes.sort()
	azules.sort()
	var m := rojos.size() / 2
	return Color(rojos[m], verdes[m], azules[m])


static func _imagen_de(cabeza: MeshInstance3D) -> Image:
	var material := cabeza.get_active_material(0)
	var textura: Texture2D = null
	if material is ShaderMaterial:
		textura = material.get_shader_parameter("textura")
	elif material is BaseMaterial3D:
		textura = material.albedo_texture
	if textura == null:
		return null
	var imagen := textura.get_image()
	if imagen == null:
		return null
	if imagen.is_compressed():
		imagen = imagen.duplicate()
		imagen.decompress()
	return imagen
