@tool
class_name EstiloToon
extends RefCounted
## Convierte materiales normales (StandardMaterial3D) al estilo toon con contorno.
## Así las escenas se arman con materiales comunes en el editor, y los modelos importados
## más adelante (glTF) reciben el mismo estilo sin tocar su lógica.
## Una malla con el metadato "sin_contorno" no recibe contorno (piso, calle, etc.).
## Las mallas con color de vértice (los personajes procesados) traen ahí una normal suavizada
## para el contorno, y llevan un contorno más delgado.

const SHADER_TOON := preload("res://materiales/toon.gdshader")
const SHADER_CONTORNO := preload("res://materiales/contorno.gdshader")

enum ModoContorno { NORMAL, CAJA, NORMAL_EN_COLOR }
const GROSOR := {ModoContorno.NORMAL: 0.035, ModoContorno.CAJA: 0.035, ModoContorno.NORMAL_EN_COLOR: 0.012}
## Cuánto se aleja el contorno de la cámara (m). En los personajes evita que se asome por orejas,
## boca y visera como astillas negras; en las cajas no hace falta.
const EMPUJE := {ModoContorno.NORMAL: 0.0, ModoContorno.CAJA: 0.0, ModoContorno.NORMAL_EN_COLOR: 0.04}

static var _materiales: Dictionary = {}
static var _contornos: Dictionary = {}


## Recorre `raiz` y todos sus descendientes aplicando el estilo a cada MeshInstance3D.
static func aplicar(raiz: Node) -> void:
	if raiz is MeshInstance3D:
		_aplicar_a_malla(raiz)
	for hijo in raiz.get_children():
		aplicar(hijo)


## Material toon de un color, con o sin contorno. Se reutiliza entre mallas iguales.
static func material(color: Color, con_contorno: bool = true, modo: ModoContorno = ModoContorno.NORMAL, textura: Texture2D = null) -> ShaderMaterial:
	var clave := [color.to_html(), con_contorno, modo, textura]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := ShaderMaterial.new()
	m.shader = SHADER_TOON
	m.set_shader_parameter("color_base", color)
	if textura != null:
		m.set_shader_parameter("textura", textura)
		m.set_shader_parameter("usar_textura", true)
	if con_contorno:
		m.next_pass = _contorno(modo)
	_materiales[clave] = m
	return m


static func _aplicar_a_malla(malla: MeshInstance3D) -> void:
	if malla.mesh == null:
		return
	var con_contorno := not malla.has_meta("sin_contorno")
	for i in malla.mesh.get_surface_count():
		var modo := ModoContorno.NORMAL
		if malla.mesh is BoxMesh:
			modo = ModoContorno.CAJA
		elif malla.mesh is ArrayMesh and malla.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR:
			modo = ModoContorno.NORMAL_EN_COLOR
		var original := malla.get_active_material(i)
		if original is ShaderMaterial:
			continue
		var color := Color.WHITE
		var textura: Texture2D = null
		if original is BaseMaterial3D:
			color = original.albedo_color
			textura = original.albedo_texture
		malla.set_surface_override_material(i, material(color, con_contorno, modo, textura))


static func _contorno(modo: ModoContorno) -> ShaderMaterial:
	if not _contornos.has(modo):
		var m := ShaderMaterial.new()
		m.shader = SHADER_CONTORNO
		m.set_shader_parameter("modo_caja", modo == ModoContorno.CAJA)
		m.set_shader_parameter("normal_en_color", modo == ModoContorno.NORMAL_EN_COLOR)
		m.set_shader_parameter("grosor", GROSOR[modo])
		m.set_shader_parameter("empuje", EMPUJE[modo])
		_contornos[modo] = m
	return _contornos[modo]
