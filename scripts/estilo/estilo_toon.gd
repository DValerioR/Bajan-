@tool
class_name EstiloToon
extends RefCounted
## Convierte materiales normales (StandardMaterial3D) al estilo toon con contorno.
## Así las escenas se arman con materiales comunes en el editor, y los modelos importados
## más adelante (glTF) reciben el mismo estilo sin tocar su lógica.
## Una malla con el metadato "sin_contorno" no recibe contorno (piso, calle, etc.).

const SHADER_TOON := preload("res://materiales/toon.gdshader")
const SHADER_CONTORNO := preload("res://materiales/contorno.gdshader")

static var _materiales: Dictionary = {}
static var _contornos: Dictionary = {}


## Recorre `raiz` y todos sus descendientes aplicando el estilo a cada MeshInstance3D.
static func aplicar(raiz: Node) -> void:
	if raiz is MeshInstance3D:
		_aplicar_a_malla(raiz)
	for hijo in raiz.get_children():
		aplicar(hijo)


## Material toon de un color, con o sin contorno. Se reutiliza entre mallas iguales.
static func material(color: Color, con_contorno: bool = true, modo_caja: bool = false, textura: Texture2D = null) -> ShaderMaterial:
	var clave := [color.to_html(), con_contorno, modo_caja, textura]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := ShaderMaterial.new()
	m.shader = SHADER_TOON
	m.set_shader_parameter("color_base", color)
	if textura != null:
		m.set_shader_parameter("textura", textura)
		m.set_shader_parameter("usar_textura", true)
	if con_contorno:
		m.next_pass = _contorno(modo_caja)
	_materiales[clave] = m
	return m


static func _aplicar_a_malla(malla: MeshInstance3D) -> void:
	if malla.mesh == null:
		return
	var con_contorno := not malla.has_meta("sin_contorno")
	var modo_caja := malla.mesh is BoxMesh
	for i in malla.mesh.get_surface_count():
		var original := malla.get_active_material(i)
		if original is ShaderMaterial:
			continue
		var color := Color.WHITE
		var textura: Texture2D = null
		if original is BaseMaterial3D:
			color = original.albedo_color
			textura = original.albedo_texture
		malla.set_surface_override_material(i, material(color, con_contorno, modo_caja, textura))


static func _contorno(modo_caja: bool) -> ShaderMaterial:
	if not _contornos.has(modo_caja):
		var m := ShaderMaterial.new()
		m.shader = SHADER_CONTORNO
		m.set_shader_parameter("modo_caja", modo_caja)
		_contornos[modo_caja] = m
	return _contornos[modo_caja]
