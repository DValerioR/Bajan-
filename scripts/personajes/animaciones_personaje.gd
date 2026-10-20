class_name AnimacionesPersonaje
extends RefCounted
## Animaciones hechas (susto, asentir, enojo, pelear) para los personajes con rig de Tripo (D53).
## Las saca scripts/herramientas/animaciones_blender.py a animaciones/<nombre>.json: por cuadro,
## cuánto gira cada hueso del juego respecto a la pose T, en los ejes de la figura. Personaje las
## mezcla con su animación de código (ver Personaje.reproducir).

const CARPETA := "res://animaciones"
const CONFIG := "res://modelos/personajes.cfg"

static var _clips: Dictionary = {}
static var _con_rig: Dictionary = {}


## La animación ya leída: {fps, cuadros, huesos: {hueso: [Quaternion]}, en_t: {hueso: Vector3},
## cadera_y: [float]}, o {} si no existe.
static func clip(nombre: String) -> Dictionary:
	if _clips.has(nombre):
		return _clips[nombre]
	var ruta := CARPETA.path_join(nombre + ".json")
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta)) if FileAccess.file_exists(ruta) else null
	var resultado := {}
	if datos is Dictionary:
		var huesos := {}
		var cuadros := 0
		for hueso in datos.huesos:
			var lista: Array[Quaternion] = []
			for q in datos.huesos[hueso]:
				lista.append(Quaternion(q[0], q[1], q[2], q[3]))
			huesos[hueso] = lista
			cuadros = lista.size()
		var en_t := {}
		for hueso in datos.en_t:
			en_t[hueso] = Vector3(datos.en_t[hueso][0], datos.en_t[hueso][1], datos.en_t[hueso][2])
		resultado = {"fps": float(datos.fps), "cuadros": cuadros, "huesos": huesos, "en_t": en_t, "cadera_y": datos.cadera_y}
	_clips[nombre] = resultado
	return resultado


## Si el modelo viene con rig de Tripo (una hoja con `rig` en personajes.cfg): solo esos se animan
## con estas animaciones (los de las hojas viejas se van a reemplazar).
static func tiene_rig(modelo: String) -> bool:
	if _con_rig.is_empty():
		var cfg := Config.archivo_config(CONFIG)
		for hoja in cfg.get_sections():
			if cfg.has_section_key(hoja, "rig"):
				for nombre in cfg.get_value(hoja, "nombres", []):
					_con_rig[nombre] = true
		_con_rig[""] = false
	return _con_rig.get(modelo, false)
