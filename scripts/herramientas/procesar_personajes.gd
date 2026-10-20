extends SceneTree
## Herramienta: convierte las hojas de personajes de Tripo (modelos/fuentes/*.glb) en
## personajes de muñeco por piezas, uno por archivo: modelos/personajes/<nombre>.glb.
## Uso: procesar_personajes.bat [--forzar [nombre ...]]
##
## Los .glb que ya existen NO se tocan: así se respetan los que se editen en Blender.
## Para regenerar uno, bórralo o usa --forzar con su nombre (--forzar solo = todos).
##
## Por cada personaje:
##   1. Lo separa de la hoja (cada personaje es una malla cerrada al soldar las costuras).
##   2. Lo centra entre los pies, lo pasa a metros y lo voltea para que mire hacia -Z.
##   3. Estima su esqueleto desde la forma: cuello, axilas, hombros, manos, entrepierna, caderas y pies.
##   4. Lo corta en Cabeza, Torso, Brazos y Piernas, asignando cada triángulo al hueso más cercano;
##      luego corta cada pierna en la rodilla, muslo (Pierna) y Pantorrilla, y cada brazo en el
##      codo, Brazo y Antebrazo.
##   5. Reduce cada pieza y la guarda con el origen en su articulación.
##   6. Recorta su parte de la textura de la hoja y la guarda dentro de su .glb.

const CONFIG := "res://modelos/personajes.cfg"
const SALIDA := "res://modelos/personajes"
const REBANADAS := 80
const COLUMNAS := 120

const PIEZAS := ["Cabeza", "Torso", "BrazoIzquierdo", "BrazoDerecho", "PiernaIzquierda", "PiernaDerecha", "PantorrillaIzquierda", "PantorrillaDerecha", "AntebrazoIzquierdo", "AntebrazoDerecho"]
const CABEZA := 0
const TORSO := 1
const BRAZO_IZQ := 2
const BRAZO_DER := 3
const PIERNA_IZQ := 4
const PIERNA_DER := 5
const PANTORRILLA_IZQ := 6
const PANTORRILLA_DER := 7
const ANTEBRAZO_IZQ := 8
const ANTEBRAZO_DER := 9
## Dónde va el codo, como fracción del camino del hombro a la mano (se cambia con `codo`).
const CODO := 0.48
## Altura de la rodilla, como fracción de la entrepierna (se cambia por personaje con `rodilla`,
## fracción de la estatura).
const RODILLA := 0.5

var _escala := 3.8
var _triangulos_objetivo := 6000
var _tamano_textura := 2048
var _resumen: Array[String] = []
var _cfg: ConfigFile
## Nombres a regenerar aunque ya existan; "*" = todos.
var _forzar: Array = []
## Con --sin-reducir las piezas salen completas y con la textura sin pérdida: las reduce después
## Blender (scripts/herramientas/tapar_cortes.py), que no abre grietas en las costuras de la textura.
var _sin_reducir := false
## Con --para-esqueleto las piezas salen completas y con los brazos como vienen (sin bajar los de la
## pose T): Blender las une en una sola malla con esqueleto (scripts/herramientas/esqueleto_blender.py).
var _para_esqueleto := false
## Carpeta de salida (--salida <carpeta>, para pruebas); por defecto modelos/personajes.
var _salida := SALIDA
## Estatura en metros de los personajes de la hoja actual (0 = usar la escala).
var _altura_objetivo := 0.0


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) != OK:
		printerr("No se pudo leer ", CONFIG)
		quit(1)
		return
	_escala = cfg.get_value("general", "escala", _escala)
	_triangulos_objetivo = cfg.get_value("general", "triangulos_por_personaje", _triangulos_objetivo)
	_tamano_textura = cfg.get_value("general", "tamano_textura", _tamano_textura)
	_cfg = cfg
	var argumentos := OS.get_cmdline_user_args()
	_para_esqueleto = argumentos.has("--para-esqueleto")
	argumentos.erase("--para-esqueleto")
	_sin_reducir = argumentos.has("--sin-reducir") or _para_esqueleto
	argumentos.erase("--sin-reducir")
	if argumentos.has("--salida"):
		var k := argumentos.find("--salida")
		_salida = argumentos[k + 1]
		argumentos.remove_at(k + 1)
		argumentos.remove_at(k)
	DirAccess.make_dir_recursive_absolute(_salida)
	if argumentos.has("--forzar"):
		_forzar = argumentos.slice(argumentos.find("--forzar") + 1)
		if _forzar.is_empty():
			_forzar = ["*"]
	var escala_general := _escala
	var textura_general := _tamano_textura
	var triangulos_general := _triangulos_objetivo
	for hoja in cfg.get_sections():
		if not cfg.has_section_key(hoja, "archivo"):
			continue
		# Cada hoja puede traer su propia escala, estatura objetivo y textura.
		_escala = cfg.get_value(hoja, "escala", escala_general)
		_altura_objetivo = cfg.get_value(hoja, "altura", 0.0)
		_tamano_textura = cfg.get_value(hoja, "tamano_textura", textura_general)
		_triangulos_objetivo = cfg.get_value(hoja, "triangulos_por_personaje", triangulos_general)
		_procesar_hoja(hoja, cfg.get_value(hoja, "archivo"), cfg.get_value(hoja, "nombres"))
	print("\nResumen:")
	for linea in _resumen:
		print(linea)
	quit(0)


func _procesar_hoja(hoja: String, archivo: String, nombres: Array) -> void:
	print("== ", hoja, " (", archivo, ")")
	var documento := GLTFDocument.new()
	var estado := GLTFState.new()
	if documento.append_from_file(archivo, estado) != OK:
		printerr("No se pudo leer ", archivo)
		return
	var escena := documento.generate_scene(estado)
	var malla_original: MeshInstance3D = escena.find_children("*", "MeshInstance3D", true, false)[0]
	var arreglos := malla_original.mesh.surface_get_arrays(0)
	var material := malla_original.get_active_material(0) as BaseMaterial3D

	# Textura de la hoja a resolución completa; cada personaje recorta su parte.
	var imagen := material.albedo_texture.get_image()
	if imagen.is_compressed():
		imagen.decompress()

	var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = arreglos[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arreglos[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arreglos[Mesh.ARRAY_INDEX]

	# Una hoja de un solo personaje se toma completa (ojos, botones y demás pedazos sueltos incluidos).
	var componentes := _separar(vertices, indices) if nombres.size() > 1 else [_todo(vertices, indices)]
	if componentes.size() != nombres.size():
		printerr("La hoja %s tiene %d personajes pero personajes.cfg nombra %d." % [hoja, componentes.size(), nombres.size()])
		return
	# Orden: fila de arriba primero (de izquierda a derecha), luego la de abajo.
	var altura_media := 0.0
	for c in componentes:
		altura_media += c.minimo.y + c.maximo.y
	altura_media /= componentes.size() * 2.0
	componentes.sort_custom(func(a, b):
		var fila_a: int = 0 if a.minimo.y > altura_media * 0.9 else 1
		var fila_b: int = 0 if b.minimo.y > altura_media * 0.9 else 1
		if fila_a != fila_b:
			return fila_a < fila_b
		return a.minimo.x < b.minimo.x)

	for k in componentes.size():
		# Un nombre vacío salta a ese personaje (por ejemplo, si ya se reemplazó con otro modelo).
		if nombres[k] != "":
			_procesar_personaje(nombres[k], componentes[k], vertices, normales, uvs, indices, imagen)


func _todo(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var g := {"triangulos": PackedInt32Array(range(0, indices.size(), 3)), "minimo": Vector3.INF, "maximo": -Vector3.INF}
	for i in indices:
		g.minimo = (g.minimo as Vector3).min(vertices[i])
		g.maximo = (g.maximo as Vector3).max(vertices[i])
	return g


## Agrupa los triángulos en personajes: soldando vértices por posición, cada personaje es una pieza.
func _separar(vertices: PackedVector3Array, indices: PackedInt32Array) -> Array:
	var padre := PackedInt32Array()
	padre.resize(vertices.size())
	for i in vertices.size():
		padre[i] = i
	var por_posicion := {}
	for i in vertices.size():
		var clave := Vector3i((vertices[i] * 20000.0).round())
		if por_posicion.has(clave):
			padre[_raiz(padre, i)] = _raiz(padre, por_posicion[clave])
		else:
			por_posicion[clave] = i
	for t in range(0, indices.size(), 3):
		var a := _raiz(padre, indices[t])
		padre[_raiz(padre, indices[t + 1])] = a
		padre[_raiz(padre, indices[t + 2])] = a
	var grupos := {}
	for t in range(0, indices.size(), 3):
		var r := _raiz(padre, indices[t])
		if not grupos.has(r):
			grupos[r] = {"triangulos": PackedInt32Array(), "minimo": Vector3.INF, "maximo": -Vector3.INF}
		grupos[r].triangulos.append(t)
	for g in grupos.values():
		for t in g.triangulos:
			for j in 3:
				var v := vertices[indices[t + j]]
				g.minimo = (g.minimo as Vector3).min(v)
				g.maximo = (g.maximo as Vector3).max(v)
	return grupos.values()


## Recorta de la hoja la zona de la textura que usa el personaje y le ajusta las coordenadas UV.
## Si sus partes están regadas por toda la hoja, se queda con la hoja completa (reducida).
## Devuelve [textura, uvs ajustadas] (los arreglos empacados se pasan por valor).
func _recortar_textura(hoja: Image, uvs: PackedVector2Array) -> Array:
	var minimo := Vector2.INF
	var maximo := -Vector2.INF
	for uv in uvs:
		minimo = minimo.min(uv)
		maximo = maximo.max(uv)
	var margen := Vector2.ONE * (8.0 / hoja.get_width())
	minimo = (minimo - margen).clamp(Vector2.ZERO, Vector2.ONE)
	maximo = (maximo + margen).clamp(Vector2.ZERO, Vector2.ONE)
	var tamano := Vector2(hoja.get_size())
	var region := Rect2i(Vector2i((minimo * tamano).floor()), Vector2i(((maximo - minimo) * tamano).ceil()))
	var recorte := hoja.get_region(region)
	# Sin reducir, la hoja va completa: Blender le arma a cada personaje su propia textura.
	var escala := 1.0 if _sin_reducir else minf(1.0, float(_tamano_textura) / maxf(region.size.x, region.size.y))
	if escala < 1.0:
		recorte.resize(maxi(1, roundi(region.size.x * escala)), maxi(1, roundi(region.size.y * escala)), Image.INTERPOLATE_LANCZOS)
	var real_min := Vector2(region.position) / tamano
	var real_tamano := Vector2(region.size) / tamano
	for i in uvs.size():
		uvs[i] = (uvs[i] - real_min) / real_tamano
	return [ImageTexture.create_from_image(recorte), uvs]


func _raiz(padre: PackedInt32Array, i: int) -> int:
	while padre[i] != i:
		padre[i] = padre[padre[i]]
		i = padre[i]
	return i


func _procesar_personaje(nombre: String, componente: Dictionary, vertices: PackedVector3Array, normales: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, hoja: Image) -> void:
	var ruta := _salida.path_join(nombre + ".glb")
	if FileAccess.file_exists(ruta) and not ("*" in _forzar or nombre in _forzar):
		_resumen.append("  %-16s ya existe: se respeta (usa --forzar %s para regenerarlo)" % [nombre, nombre])
		return
	var minimo: Vector3 = componente.minimo
	var maximo: Vector3 = componente.maximo
	var centro := Vector3((minimo.x + maximo.x) * 0.5, minimo.y, (minimo.z + maximo.z) * 0.5)
	var escala := _escala if _altura_objetivo <= 0.0 else _altura_objetivo / (maximo.y - minimo.y)
	# Del modelo original (mira hacia +Z) a coordenadas del juego: metros, pies en y = 0, mirando a -Z.
	var a_local := func(v: Vector3) -> Vector3:
		var d := (v - centro) * escala
		return Vector3(-d.x, d.y, -d.z)

	# Vértices usados por este personaje, ya en coordenadas locales.
	var mapa := {}
	var locales := PackedVector3Array()
	var normales_locales := PackedVector3Array()
	var uvs_locales := PackedVector2Array()
	var triangulos := PackedInt32Array()
	for t in componente.triangulos:
		for j in 3:
			var i := indices[t + j]
			if not mapa.has(i):
				mapa[i] = locales.size()
				locales.append(a_local.call(vertices[i]))
				var n := normales[i]
				normales_locales.append(Vector3(-n.x, n.y, -n.z))
				uvs_locales.append(uvs[i])
			triangulos.append(mapa[i])

	var esqueleto := _estimar_esqueleto(locales)
	_aplicar_medidas(esqueleto, nombre)
	print("    %s: altura %.2f | entrepierna %.2f (%.0f%%) | axila %.2f (%.0f%%) brazos sueltos %s | cuello %.2f (%.0f%%) | torso medio %.2f | manos %s %s" % [nombre, esqueleto.altura, esqueleto.entrepierna, esqueleto.entrepierna / esqueleto.altura * 100.0, esqueleto.axila, esqueleto.axila / esqueleto.altura * 100.0, esqueleto.brazos_sueltos, esqueleto.cuello, esqueleto.cuello / esqueleto.altura * 100.0, esqueleto.torso_medio, esqueleto.mano_izq, esqueleto.mano_der])
	var etiquetas := _etiquetar(locales, triangulos, esqueleto)
	_limpiar_islas(locales, triangulos, etiquetas)
	_cortar_rodillas(locales, triangulos, etiquetas, esqueleto, nombre)
	_cortar_codos(locales, triangulos, etiquetas, esqueleto, nombre)

	var raiz := Node3D.new()
	raiz.name = nombre
	var material := StandardMaterial3D.new()
	material.resource_name = nombre
	var recorte := _recortar_textura(hoja, uvs_locales)
	material.albedo_texture = recorte[0]
	uvs_locales = recorte[1]
	var total_triangulos := triangulos.size() / 3
	var triangulos_finales := 0
	var conteo_piezas: Array[int] = []
	for p in PIEZAS.size():
		var pivote: Vector3 = esqueleto.pivotes[p]
		var giro := Basis()
		var posicion := pivote
		if esqueleto.has("brazos_caidos") and not _para_esqueleto and p in [BRAZO_IZQ, BRAZO_DER, ANTEBRAZO_IZQ, ANTEBRAZO_DER]:
			# Pose T: todo el brazo (con su antebrazo) baja girando sobre el hombro.
			var izquierdo := p in [BRAZO_IZQ, ANTEBRAZO_IZQ]
			var hombro: Vector3 = esqueleto.pivotes[BRAZO_IZQ if izquierdo else BRAZO_DER]
			giro = _bajar_brazo(hombro, esqueleto.mano_izq if izquierdo else esqueleto.mano_der, esqueleto.brazos_caidos)
			posicion = hombro + giro * (pivote - hombro)
		var malla := _construir_pieza(p, etiquetas, triangulos, locales, normales_locales, uvs_locales, pivote, total_triangulos, giro)
		var nodo := MeshInstance3D.new()
		nodo.name = PIEZAS[p]
		nodo.position = posicion
		if malla != null:
			malla.surface_set_material(0, material)
			nodo.mesh = malla
			var n := malla.surface_get_array_index_len(0) / 3
			triangulos_finales += n
			conteo_piezas.append(n)
		else:
			conteo_piezas.append(0)
		raiz.add_child(nodo)
		nodo.owner = raiz

	# Un .glb por personaje, con la textura adentro. El juego saca alturas y manos de las piezas.
	var documento := GLTFDocument.new()
	documento.image_format = "PNG" if _sin_reducir else "JPEG"
	documento.lossy_quality = 0.88
	var estado := GLTFState.new()
	documento.append_from_scene(raiz, estado)
	var error := documento.write_to_filesystem(estado, ProjectSettings.globalize_path(ruta))
	if error != OK:
		printerr("No se pudo guardar ", ruta, " (error ", error, ")")
	raiz.free()
	_resumen.append("  %-16s altura %.2f m | %6d → %5d triángulos | piezas %s" % [nombre, esqueleto.altura, total_triangulos, triangulos_finales, str(conteo_piezas)])
	print("  ", nombre, " listo")


## Estima articulaciones a partir de rebanadas horizontales del personaje (vista de frente).
func _estimar_esqueleto(puntos: PackedVector3Array) -> Dictionary:
	var minimo := Vector3.INF
	var maximo := -Vector3.INF
	for p in puntos:
		minimo = minimo.min(p)
		maximo = maximo.max(p)
	var altura := maximo.y
	var ancho_x := maxf(-minimo.x, maximo.x)
	var dy := altura / REBANADAS
	var dx := ancho_x * 2.0 / COLUMNAS

	# Ocupación por rebanada y columna (cuántos vértices caen en cada celda).
	var ocupacion := PackedInt32Array()
	ocupacion.resize(REBANADAS * COLUMNAS)
	for p in puntos:
		var r := clampi(int(p.y / dy), 0, REBANADAS - 1)
		var c := clampi(int((p.x + ancho_x) / dx), 0, COLUMNAS - 1)
		ocupacion[r * COLUMNAS + c] += 1
	var tramos: Array = []
	for r in REBANADAS:
		var lista: Array = []
		var inicio := -1
		for c in COLUMNAS + 1:
			var lleno := c < COLUMNAS and ocupacion[r * COLUMNAS + c] >= 2
			if lleno and inicio < 0:
				inicio = c
			elif not lleno and inicio >= 0:
				lista.append(Vector2(-ancho_x + inicio * dx, -ancho_x + c * dx))
				inicio = -1
		tramos.append(lista)
	var columna_centro := COLUMNAS / 2

	# Entrepierna: desde abajo, primera rebanada donde la columna central se llena y sigue llena.
	var entrepierna := altura * 0.3
	var centro_vacio_abajo := false
	for r in range(1, int(REBANADAS * 0.7)):
		var lleno := ocupacion[r * COLUMNAS + columna_centro] + ocupacion[r * COLUMNAS + columna_centro - 1] >= 2
		if not lleno:
			centro_vacio_abajo = true
		elif centro_vacio_abajo:
			entrepierna = r * dy
			break
	entrepierna = clampf(entrepierna, altura * 0.12, altura * 0.55)

	# Torso: el tramo que contiene el centro. Axilas: la rebanada más alta con tramos sueltos a los lados.
	var axila := -1.0
	var torso_medio := ancho_x * 0.5
	for r in range(int(entrepierna / dy) + 1, int(REBANADAS * 0.9)):
		var torso := _tramo_central(tramos[r])
		if torso == Vector2.ZERO:
			continue
		var izquierda := false
		var derecha := false
		for t in tramos[r]:
			if t.y < torso.x:
				izquierda = true
			elif t.x > torso.y:
				derecha = true
		if izquierda and derecha:
			axila = r * dy
			torso_medio = (torso.y - torso.x) * 0.5
	var brazos_sueltos := axila > 0.0
	if not brazos_sueltos:
		axila = entrepierna + (altura - entrepierna) * 0.42

	# Cuello: el punto más angosto del tramo central entre las axilas y la cabeza.
	var cuello := axila + (altura - axila) * 0.35
	var ancho_minimo := INF
	for r in range(int((axila + altura * 0.03) / dy), int((axila + (altura - axila) * 0.6) / dy)):
		var torso := _tramo_central(tramos[r])
		if torso == Vector2.ZERO:
			continue
		var w := torso.y - torso.x
		if w < ancho_minimo:
			ancho_minimo = w
			cuello = r * dy
	cuello = clampf(cuello, axila + altura * 0.02, altura * 0.9)

	# Manos: siguiendo el tramo más exterior de cada lado desde la axila hacia abajo.
	var mano_izq := Vector3(-torso_medio * 1.6, entrepierna, 0.0)
	var mano_der := Vector3(torso_medio * 1.6, entrepierna, 0.0)
	if brazos_sueltos:
		mano_izq = _seguir_brazo(tramos, int(axila / dy), -1, dy, mano_izq)
		mano_der = _seguir_brazo(tramos, int(axila / dy), 1, dy, mano_der)

	var hombro_y := axila + altura * 0.05
	var hombro_x := torso_medio * 0.85
	# Caderas: a media distancia entre el centro y cada pie.
	var pie_izq := Vector3.ZERO
	var pie_der := Vector3.ZERO
	var n_izq := 0
	var n_der := 0
	for p in puntos:
		if p.y < altura * 0.06:
			if p.x < 0.0:
				pie_izq += p
				n_izq += 1
			else:
				pie_der += p
				n_der += 1
	pie_izq = pie_izq / maxi(n_izq, 1)
	pie_der = pie_der / maxi(n_der, 1)
	var cadera_x := maxf(absf(pie_izq.x), absf(pie_der.x)) * 0.8
	cadera_x = clampf(cadera_x, torso_medio * 0.3, torso_medio * 0.8)

	var pivotes: Array[Vector3] = []
	pivotes.resize(PIEZAS.size())
	pivotes[CABEZA] = Vector3(0.0, cuello, 0.0)
	pivotes[TORSO] = Vector3(0.0, entrepierna, 0.0)
	pivotes[BRAZO_IZQ] = Vector3(-hombro_x, hombro_y, 0.0)
	pivotes[BRAZO_DER] = Vector3(hombro_x, hombro_y, 0.0)
	pivotes[PIERNA_IZQ] = Vector3(-cadera_x, entrepierna, 0.0)
	pivotes[PIERNA_DER] = Vector3(cadera_x, entrepierna, 0.0)
	return {
		"altura": altura,
		"altura_ojos": cuello + (altura - cuello) * 0.45,
		"ancho": ancho_x * 2.0,
		"entrepierna": entrepierna,
		"cuello": cuello,
		"axila": axila,
		"brazos_sueltos": brazos_sueltos,
		"torso_medio": torso_medio,
		"mano_izq": mano_izq,
		"mano_der": mano_der,
		"pie_izq": Vector3(pie_izq.x, 0.0, 0.0),
		"pie_der": Vector3(pie_der.x, 0.0, 0.0),
		"pivotes": pivotes,
	}


## Si personajes.cfg trae las articulaciones medidas a mano, reemplazan a las estimadas.
func _aplicar_medidas(e: Dictionary, nombre: String) -> void:
	if not _cfg.has_section(nombre):
		print("    (sin medidas a mano: se usan las estimadas)")
		return
	var h: float = e.altura
	var cuello: float = _cfg.get_value(nombre, "cuello") * h
	var axila: float = _cfg.get_value(nombre, "axila") * h
	var entrepierna: float = _cfg.get_value(nombre, "entrepierna") * h
	var mano_x: float = _cfg.get_value(nombre, "mano_x") * h
	var mano_y: float = _cfg.get_value(nombre, "mano_y") * h
	var hombro_x: float = _cfg.get_value(nombre, "hombro_x") * h
	var hombro_y := minf(axila + h * 0.06, cuello - h * 0.02)
	var cadera_x := clampf(absf(e.pie_izq.x) * 0.8, hombro_x * 0.3, hombro_x * 0.8)
	e.cuello = cuello
	e.axila = axila
	e.entrepierna = entrepierna
	e.torso_medio = hombro_x
	e.altura_ojos = cuello + (h - cuello) * 0.45
	e.mano_izq = Vector3(-mano_x, mano_y, 0.0)
	e.mano_der = Vector3(mano_x, mano_y, 0.0)
	e.pivotes[CABEZA] = Vector3(0.0, cuello, 0.0)
	e.pivotes[TORSO] = Vector3(0.0, entrepierna, 0.0)
	e.pivotes[BRAZO_IZQ] = Vector3(-hombro_x, hombro_y, 0.0)
	e.pivotes[BRAZO_DER] = Vector3(hombro_x, hombro_y, 0.0)
	e.pivotes[PIERNA_IZQ] = Vector3(-cadera_x, entrepierna, 0.0)
	e.pivotes[PIERNA_DER] = Vector3(cadera_x, entrepierna, 0.0)
	if _cfg.has_section_key(nombre, "cara_x"):
		e.cara_x = float(_cfg.get_value(nombre, "cara_x")) * h
	if _cfg.has_section_key(nombre, "nuca_z"):
		e.nuca_z = float(_cfg.get_value(nombre, "nuca_z")) * h
	if _cfg.get_value(nombre, "manga_con_brazo", false):
		e.manga_con_brazo = true
	# Modelos en pose T: los brazos se cortan extendidos y se bajan (grados desde la vertical).
	if _cfg.has_section_key(nombre, "brazos_caidos"):
		e.brazos_caidos = float(_cfg.get_value(nombre, "brazos_caidos"))
		e.hombro_x = hombro_x


## Giro (sobre Z, alrededor del hombro) que deja colgando un brazo extendido, abierto
## `grados` desde la vertical: la animación da por hecho que los brazos cuelgan en reposo.
func _bajar_brazo(hombro: Vector3, mano: Vector3, grados: float) -> Basis:
	var actual := Vector2(mano.x - hombro.x, mano.y - hombro.y)
	var lado := signf(mano.x)
	var objetivo := Vector2(lado * sin(deg_to_rad(grados)), -cos(deg_to_rad(grados)))
	return Basis(Vector3.BACK, actual.angle_to(objetivo))


func _tramo_central(lista: Array) -> Vector2:
	var mejor := Vector2.ZERO
	var mejor_distancia := INF
	for t in lista:
		if t.x <= 0.0 and t.y >= 0.0:
			return t
		var d := minf(absf(t.x), absf(t.y))
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = t
	return mejor


## Baja rebanada por rebanada siguiendo el tramo más exterior de un lado mientras siga conectado.
func _seguir_brazo(tramos: Array, desde: int, lado: int, dy: float, por_defecto: Vector3) -> Vector3:
	var anterior := Vector2.ZERO
	var ultima := -1
	for r in range(desde, -1, -1):
		var lista: Array = tramos[r]
		if lista.is_empty():
			break
		var exterior: Vector2 = lista[0] if lado < 0 else lista[lista.size() - 1]
		if anterior != Vector2.ZERO and (exterior.y < anterior.x - dy or exterior.x > anterior.y + dy):
			break
		anterior = exterior
		ultima = r
	if ultima < 0:
		return por_defecto
	return Vector3((anterior.x + anterior.y) * 0.5, ultima * dy, 0.0)


## Asigna cada triángulo a una pieza según el hueso más cercano (distancia normalizada por grosor).
func _etiquetar(puntos: PackedVector3Array, triangulos: PackedInt32Array, e: Dictionary) -> PackedByteArray:
	var etiquetas := PackedByteArray()
	etiquetas.resize(triangulos.size() / 3)
	var altura: float = e.altura
	var cuello: float = e.cuello
	var entrepierna: float = e.entrepierna
	var piv: Array = e.pivotes
	var radio_torso: float = maxf(e.torso_medio, altura * 0.08)
	var radio_brazo := maxf(altura * 0.045, float(e.torso_medio) * 0.35)
	var radio_pierna := altura * 0.07
	var hombro_tope: float = piv[BRAZO_IZQ].y + altura * 0.04
	# Profundidad de cada brazo (la de su mano): el brazo es un cilindro, no una rebanada de todo
	# el grueso del cuerpo. Así la ropa de los costados que queda adelante o atrás del brazo es torso.
	var z_brazo := {BRAZO_IZQ: _profundidad_cerca(puntos, e.mano_izq, altura * 0.06), BRAZO_DER: _profundidad_cerca(puntos, e.mano_der, altura * 0.06)}
	var huesos := [
		[TORSO, Vector2(0.0, entrepierna), Vector2(0.0, cuello), radio_torso],
		[BRAZO_IZQ, Vector2(piv[BRAZO_IZQ].x, piv[BRAZO_IZQ].y), Vector2(e.mano_izq.x, e.mano_izq.y), radio_brazo],
		[BRAZO_DER, Vector2(piv[BRAZO_DER].x, piv[BRAZO_DER].y), Vector2(e.mano_der.x, e.mano_der.y), radio_brazo],
		[PIERNA_IZQ, Vector2(piv[PIERNA_IZQ].x, entrepierna), Vector2(e.pie_izq.x, 0.0), radio_pierna],
		[PIERNA_DER, Vector2(piv[PIERNA_DER].x, entrepierna), Vector2(e.pie_der.x, 0.0), radio_pierna],
	]
	for t in range(0, triangulos.size(), 3):
		var c := (puntos[triangulos[t]] + puntos[triangulos[t + 1]] + puntos[triangulos[t + 2]]) / 3.0
		var etiqueta := TORSO
		# En pose T, lo que queda arriba del cuello pero lejos del centro es la mano (el pulgar), no la cabeza.
		if c.y > cuello and not (e.has("brazos_caidos") and absf(c.x) > float(e.hombro_x)):
			etiqueta = CABEZA
			# En los de hombros altos (o encorvados) la parte de arriba de los hombros también queda
			# sobre esa línea: justo arriba del cuello, lo que queda más afuera que la cara (cara_x)
			# es hombro y lo que queda más atrás que la nuca (nuca_z) es espalda. Más arriba ya todo
			# es cabeza (orejas, lentes, sombrero).
			if c.y < cuello + (altura - cuello) * 0.3:
				if e.has("cara_x") and absf(c.x) > float(e.cara_x):
					etiqueta = TORSO
				elif e.has("nuca_z") and c.z > float(e.nuca_z):
					etiqueta = TORSO
		else:
			var p := Vector2(c.x, c.y)
			var mejor := INF
			for h in huesos:
				var pieza: int = h[0]
				if pieza == TORSO and c.y < entrepierna - altura * 0.02:
					continue
				if (pieza == PIERNA_IZQ or pieza == PIERNA_DER) and c.y > entrepierna + altura * 0.03:
					continue
				# Las piernas no se quedan con lo que está lejos de su columna (manos que cuelgan al lado).
				if (pieza == PIERNA_IZQ or pieza == PIERNA_DER) and absf(c.x - (h[2] as Vector2).x) > altura * 0.13:
					continue
				if pieza == BRAZO_IZQ or pieza == BRAZO_DER:
					if e.has("brazos_caidos"):
						# En pose T el brazo empieza en el hombro: lo que queda adentro es pecho o espalda.
						if absf(c.x) < float(e.hombro_x) - altura * 0.01:
							continue
					elif c.y > hombro_tope:
						continue
				var d := _distancia_segmento(p, h[1], h[2])
				# En pose T el brazo va acostado y se baja después: ahí basta con la vista de frente.
				if z_brazo.has(pieza) and not e.has("brazos_caidos"):
					d = Vector2(d, c.z - float(z_brazo[pieza])).length()
				d /= float(h[3])
				# Manga corta y ancha: desde un poco abajo de la axila (donde termina la manga) y por
				# fuera del costado, todo es del brazo, así la manga se levanta con él y no se queda
				# vacía colgando del torso.
				if e.has("manga_con_brazo") and z_brazo.has(pieza) and c.y > float(e.axila) - altura * 0.08 and absf(c.x) > absf(float(piv[BRAZO_IZQ].x)) * 0.85 and signf(c.x) == signf((h[1] as Vector2).x):
					d = 0.0
				if d < mejor:
					mejor = d
					etiqueta = pieza
		etiquetas[t / 3] = etiqueta
	return etiquetas


## Corta cada pierna en la rodilla: lo de abajo pasa a la pantorrilla, con su pivote en la rodilla
## (a la profundidad de la pierna ahí, para que doble sobre su eje). La altura sale de `rodilla` en
## personajes.cfg (fracción de la estatura) o es la mitad de la entrepierna.
func _cortar_rodillas(puntos: PackedVector3Array, triangulos: PackedInt32Array, etiquetas: PackedByteArray, e: Dictionary, nombre: String) -> void:
	var altura: float = e.altura
	var rodilla: float = float(_cfg.get_value(nombre, "rodilla", 0.0)) * altura
	if rodilla <= 0.0:
		rodilla = float(e.entrepierna) * RODILLA
	e.rodilla = rodilla
	for par in [[PIERNA_IZQ, PANTORRILLA_IZQ], [PIERNA_DER, PANTORRILLA_DER]]:
		var pierna: int = par[0]
		var pantorrilla: int = par[1]
		# Centro de la pierna a la altura de la rodilla (x y z promedio de sus vértices ahí).
		var suma := Vector3.ZERO
		var cuantos := 0
		for t in range(0, triangulos.size(), 3):
			if etiquetas[t / 3] != pierna:
				continue
			for j in 3:
				var v := puntos[triangulos[t + j]]
				if absf(v.y - rodilla) < altura * 0.025:
					suma += v
					cuantos += 1
		var cadera: Vector3 = e.pivotes[pierna]
		var centro := suma / cuantos if cuantos > 0 else Vector3(cadera.x, rodilla, 0.0)
		e.pivotes[pantorrilla] = Vector3(centro.x, rodilla, centro.z)
		for t in range(0, triangulos.size(), 3):
			if etiquetas[t / 3] != pierna:
				continue
			var c := (puntos[triangulos[t]] + puntos[triangulos[t + 1]] + puntos[triangulos[t + 2]]) / 3.0
			if c.y < rodilla:
				etiquetas[t / 3] = pantorrilla


## Corta cada brazo en el codo, a `codo` (fracción, por personaje) del camino del hombro a la mano:
## lo que queda más allá pasa al antebrazo, con su pivote en el codo (a la profundidad del brazo).
func _cortar_codos(puntos: PackedVector3Array, triangulos: PackedInt32Array, etiquetas: PackedByteArray, e: Dictionary, nombre: String) -> void:
	var fraccion: float = float(_cfg.get_value(nombre, "codo", CODO))
	var altura: float = e.altura
	for datos in [[BRAZO_IZQ, ANTEBRAZO_IZQ, e.mano_izq], [BRAZO_DER, ANTEBRAZO_DER, e.mano_der]]:
		var brazo: int = datos[0]
		var antebrazo: int = datos[1]
		var hombro: Vector3 = e.pivotes[brazo]
		var mano: Vector3 = datos[2]
		var a := Vector2(hombro.x, hombro.y)
		var ab := Vector2(mano.x, mano.y) - a
		if ab.length_squared() < 0.0001:
			e.pivotes[antebrazo] = hombro
			continue
		var codo := a + ab * fraccion
		# Profundidad del brazo en el codo.
		var suma := 0.0
		var cuantos := 0
		for t in range(0, triangulos.size(), 3):
			if etiquetas[t / 3] != brazo:
				continue
			for j in 3:
				var v := puntos[triangulos[t + j]]
				if Vector2(v.x, v.y).distance_to(codo) < altura * 0.03:
					suma += v.z
					cuantos += 1
		e.pivotes[antebrazo] = Vector3(codo.x, codo.y, suma / cuantos if cuantos > 0 else hombro.z)
		for t in range(0, triangulos.size(), 3):
			if etiquetas[t / 3] != brazo:
				continue
			var c := (puntos[triangulos[t]] + puntos[triangulos[t + 1]] + puntos[triangulos[t + 2]]) / 3.0
			if (Vector2(c.x, c.y) - a).dot(ab) / ab.length_squared() > fraccion:
				etiquetas[t / 3] = antebrazo


## Las islas chicas de una pieza (por ejemplo, puntas de dedos que quedaron en la pierna) se pasan a la
## pieza vecina con la que comparten más vértices, para que no queden pedazos flotando al mover la articulación.
func _limpiar_islas(puntos: PackedVector3Array, triangulos: PackedInt32Array, etiquetas: PackedByteArray) -> void:
	var n := etiquetas.size()
	# Vértices soldados por posición, para que las costuras de textura no corten las islas.
	var soldado := PackedInt32Array()
	soldado.resize(puntos.size())
	var por_posicion := {}
	for i in puntos.size():
		var clave := Vector3i((puntos[i] * 5000.0).round())
		soldado[i] = por_posicion.get(clave, i)
		por_posicion[clave] = soldado[i]
	var triangulos_de := {}
	for t in n:
		for j in 3:
			var v := soldado[triangulos[t * 3 + j]]
			if not triangulos_de.has(v):
				triangulos_de[v] = PackedInt32Array()
			triangulos_de[v].append(t)
	for _pasada in 2:
		var visto := PackedByteArray()
		visto.resize(n)
		var tamano_mayor := {}
		var islas: Array = []
		for t in n:
			if visto[t]:
				continue
			var pieza := etiquetas[t]
			var isla := PackedInt32Array([t])
			visto[t] = 1
			var vecinos := {}
			var k := 0
			while k < isla.size():
				var actual := isla[k]
				k += 1
				for j in 3:
					for otro in triangulos_de[soldado[triangulos[actual * 3 + j]]]:
						if etiquetas[otro] == pieza:
							if not visto[otro]:
								visto[otro] = 1
								isla.append(otro)
						else:
							vecinos[etiquetas[otro]] = vecinos.get(etiquetas[otro], 0) + 1
			islas.append([pieza, isla, vecinos])
			tamano_mayor[pieza] = maxi(tamano_mayor.get(pieza, 0), isla.size())
		var cambios := 0
		for datos in islas:
			var isla: PackedInt32Array = datos[1]
			if isla.size() >= tamano_mayor[datos[0]] * 0.2:
				continue
			if (datos[2] as Dictionary).is_empty():
				# Pedazo suelto que no toca a nadie (un mechón, un arete): va con la pieza que tenga más cerca.
				var cercana := _pieza_mas_cercana(puntos, triangulos, etiquetas, isla)
				if cercana >= 0 and cercana != datos[0]:
					for t in isla:
						etiquetas[t] = cercana
					cambios += 1
				continue
			var mejor := -1
			var mejor_conteo := -1
			for pieza in datos[2]:
				if datos[2][pieza] > mejor_conteo:
					mejor_conteo = datos[2][pieza]
					mejor = pieza
			for t in isla:
				etiquetas[t] = mejor
			cambios += 1
		if cambios == 0:
			break


## Profundidad (z) promedio de los vértices cerca de `punto`, visto de frente.
func _profundidad_cerca(puntos: PackedVector3Array, punto: Vector3, radio: float) -> float:
	var suma := 0.0
	var n := 0
	for q in puntos:
		if Vector2(q.x - punto.x, q.y - punto.y).length() < radio:
			suma += q.z
			n += 1
	return suma / n if n > 0 else 0.0


## La pieza del triángulo más cercano al centro de la isla, sin contar a la isla misma (-1 si no hay).
func _pieza_mas_cercana(puntos: PackedVector3Array, triangulos: PackedInt32Array, etiquetas: PackedByteArray, isla: PackedInt32Array) -> int:
	var propios := {}
	var centro := Vector3.ZERO
	for t in isla:
		propios[t] = true
		centro += puntos[triangulos[t * 3]]
	centro /= isla.size()
	var mejor := -1
	var mejor_distancia := INF
	for t in etiquetas.size():
		if propios.has(t):
			continue
		var d := puntos[triangulos[t * 3]].distance_squared_to(centro)
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = etiquetas[t]
	return mejor


func _distancia_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 0.000001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Arma la malla de una pieza, la reduce y la deja con el origen en su articulación.
func _construir_pieza(pieza: int, etiquetas: PackedByteArray, triangulos: PackedInt32Array, puntos: PackedVector3Array, normales: PackedVector3Array, uvs: PackedVector2Array, pivote: Vector3, total_triangulos: int, giro: Basis = Basis()) -> ArrayMesh:
	var mapa := {}
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for t in etiquetas.size():
		if etiquetas[t] != pieza:
			continue
		for j in 3:
			var i := triangulos[t * 3 + j]
			if not mapa.has(i):
				mapa[i] = v.size()
				v.append(giro * (puntos[i] - pivote))
				n.append(giro * normales[i])
				uv.append(uvs[i])
			idx.append(mapa[i])
	if idx.is_empty():
		return null
	var arreglos := []
	arreglos.resize(Mesh.ARRAY_MAX)
	arreglos[Mesh.ARRAY_VERTEX] = v
	arreglos[Mesh.ARRAY_NORMAL] = n
	arreglos[Mesh.ARRAY_TEX_UV] = uv
	arreglos[Mesh.ARRAY_INDEX] = idx
	if _triangulos_objetivo <= 0 or _sin_reducir:
		var completa := ArrayMesh.new()
		completa.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
		completa.resource_name = PIEZAS[pieza]
		return completa

	# Reducción con los niveles de detalle (LOD) de Godot: se toma el nivel más cercano al objetivo.
	var objetivo := maxi(60, roundi(float(_triangulos_objetivo) * (idx.size() / 3) / total_triangulos))
	var importadora := ImporterMesh.new()
	importadora.add_surface(Mesh.PRIMITIVE_TRIANGLES, arreglos)
	importadora.generate_lods(25.0, 60.0, [])
	var mejores := idx
	for nivel in importadora.get_surface_lod_count(0):
		var candidatos := importadora.get_surface_lod_indices(0, nivel)
		if candidatos.size() / 3 >= objetivo * 0.6:
			mejores = candidatos
	# Quedarse solo con los vértices que usa el nivel elegido.
	var usado := {}
	var v2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var idx2 := PackedInt32Array()
	var datos: Array = importadora.get_surface_arrays(0)
	var vv: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
	var uu: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
	for i in mejores:
		if not usado.has(i):
			usado[i] = v2.size()
			v2.append(vv[i])
			n2.append(nn[i])
			uv2.append(uu[i])
		idx2.append(usado[i])
	var final := []
	final.resize(Mesh.ARRAY_MAX)
	final[Mesh.ARRAY_VERTEX] = v2
	final[Mesh.ARRAY_NORMAL] = n2
	final[Mesh.ARRAY_TEX_UV] = uv2
	final[Mesh.ARRAY_INDEX] = idx2
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, final)
	malla.resource_name = PIEZAS[pieza]
	return malla
