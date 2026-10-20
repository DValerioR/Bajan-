class_name CaraPersonaje
extends RefCounted
## Cara animada de un personaje: párpados que parpadean y boca que se abre al hablar o gritar. La
## boca son dos claves de forma de la malla ("Cerrar" y "Abrir") que pone Blender
## (scripts/herramientas/caras_blender.py) a partir de `boca` en modelos/personajes.cfg. Los
## párpados se arman aquí al cargar, con `ojos`, y van pegados al hueso de la cabeza:
##   ojos = [[x, y, radio, (radio_y)], ...]  centro de cada ojo (m, coordenadas de la figura, pies
##          en 0); con radio_y el párpado es un óvalo (para ojos almendrados)
##   cara_giro = grados hacia donde ve la cara (0 = al frente), para los de cabeza volteada.
## La malla se dibuja también por dentro, en oscuro: al abrirse la boca se ve su interior.
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


## Arma la cara sobre la malla del personaje (ya con su material toon). `en_figura` lleva del
## esqueleto a la figura. Devuelve {} si el modelo no tiene cara animada, o {malla: la malla si
## tiene boca (si no, null), cerrar: índice de la clave, abrir: índice, parpados: [ShaderMaterial]}.
static func armar(modelo: String, malla: MeshInstance3D, esqueleto: Skeleton3D, en_figura: Transform3D) -> Dictionary:
	if malla == null or malla.mesh == null:
		return {}
	var cfg := Config.archivo_config(CONFIG)
	var cerrar := -1
	var abrir := -1
	for b in malla.mesh.get_blend_shape_count():
		match String(malla.mesh.get_blend_shape_name(b)):
			"Cerrar":
				cerrar = b
			"Abrir":
				abrir = b
	var con_boca := cerrar >= 0 and abrir >= 0
	if not con_boca and not cfg.has_section_key(modelo, "ojos"):
		return {}
	var resultado := {"malla": malla if con_boca else null, "cerrar": cerrar, "abrir": abrir, "parpados": []}
	if not _hechas.has(modelo):
		_hechas[modelo] = _preparar(modelo, malla, en_figura * malla.transform, cfg)
	var hecha: Dictionary = _hechas[modelo]
	if con_boca:
		malla.set_surface_override_material(0, _material_cabeza(malla.get_active_material(0) as ShaderMaterial))
		malla.set_blend_shape_value(cerrar, 1.0)
	var cabeza := esqueleto.find_bone("Cabeza")
	if cabeza < 0 or hecha.get("parpados", []).is_empty():
		return resultado
	# Los párpados siguen al hueso de la cabeza; dentro, van en coordenadas de la figura.
	var pegado := BoneAttachment3D.new()
	pegado.name = "Parpados"
	pegado.bone_name = "Cabeza"
	esqueleto.add_child(pegado)
	var en_cabeza := Node3D.new()
	en_cabeza.transform = esqueleto.get_bone_global_rest(cabeza).affine_inverse() * en_figura.affine_inverse()
	pegado.add_child(en_cabeza)
	for datos in hecha.parpados:
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
		en_cabeza.add_child(parpado)
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


## Las mallas de los párpados, en coordenadas de la figura (`a_figura` lleva de la malla a la figura).
static func _preparar(modelo: String, cuerpo: MeshInstance3D, a_figura: Transform3D, cfg: ConfigFile) -> Dictionary:
	var hecha := {}
	var malla := cuerpo.mesh
	var arreglos: Array = malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = (arreglos[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	for i in vertices.size():
		vertices[i] = a_figura * vertices[i]
	var normales: PackedVector3Array = arreglos[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(vertices.size())
		for i in vertices.size():
			indices[i] = i
	var origen := Vector3.ZERO
	var giro := deg_to_rad(float(cfg.get_value(modelo, "cara_giro", 0.0)))
	# Hacia dónde ve la cara (en el plano del piso; el frente de la figura es -Z).
	var frente := Vector3(-sin(giro), 0.0, -cos(giro))
	var adelante := func(p: Vector3) -> float: return p.x * frente.x + p.z * frente.z

	if cfg.has_section_key(modelo, "ojos"):
		var imagen := _imagen_de(cuerpo)
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
			var alto := tamano * (float(ojo[3]) / radio if ojo.size() > 3 else 1.0)
			var centro_esfera := punta - frente * tamano * (1.0 - SOBRESALE_PARPADO) - origen
			centro_esfera.y = centro.y - origen.y
			parpados.append({
				"malla": _malla_parpado(centro_esfera, tamano, alto),
				"color": color_piel,
				"tope": centro_esfera.y + alto,
				"fondo": centro_esfera.y - alto,
			})
		hecha.parpados = parpados
	return hecha


static func _malla_parpado(centro: Vector3, radio: float, alto: float) -> ArrayMesh:
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 20
	esfera.rings = 12
	var datos := esfera.get_mesh_arrays()
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i].y *= alto / radio
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
