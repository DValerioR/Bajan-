class_name PistaPrueba
extends Node3D
## Calle de prueba de la etapa 1, armada desde config/calle_prueba.cfg:
## dos carriles con baches, banquetas, topes, edificios y árboles.
## También sirve de "línea de ruta": guarda una muestra por metro del centro de la calle,
## que usan el reinicio del camión y, más adelante, los bots.

const RUTA := "res://config/calle_prueba.cfg"
const PASO := 1.0
const SOLAPE := 0.35

const COLOR_ASFALTO := Color(0.27, 0.27, 0.3)
const COLOR_BANQUETA := Color(0.74, 0.71, 0.66)
const COLOR_GUARNICION := Color(0.98, 0.8, 0.2)
const COLOR_RAYA := Color(0.95, 0.95, 0.92)
const COLOR_PISO := Color(0.6, 0.62, 0.4)
const COLOR_BACHE := Color(0.2, 0.17, 0.15)
const COLOR_TOPE := Color(1.0, 0.82, 0.12)
const COLOR_TINACO := Color(0.12, 0.12, 0.14)
const COLOR_TRONCO := Color(0.45, 0.3, 0.2)
const COLOR_FOLLAJE := Color(0.3, 0.62, 0.3)
const COLORES_FACHADA := [
	Color(0.9, 0.3, 0.55), Color(0.22, 0.38, 0.72), Color(0.98, 0.78, 0.3), Color(0.82, 0.42, 0.28),
	Color(0.36, 0.76, 0.66), Color(0.95, 0.56, 0.2), Color(0.93, 0.9, 0.84),
]

## Centro de la calle, una muestra por metro.
var puntos := PackedVector3Array()
## Dirección de avance en cada muestra.
var direcciones := PackedVector3Array()
var longitud: float = 0.0

var ancho_carril := 3.6
var alto_calle := 0.25
var ancho_banqueta := 2.2
var alto_banqueta := 0.17

var _cuerpo: StaticBody3D
var _cajas_visuales: Dictionary = {}


func _ready() -> void:
	var c := Config.archivo_config(RUTA)
	ancho_carril = c.get_value("calle", "ancho_carril", ancho_carril)
	alto_calle = c.get_value("calle", "alto_calle", alto_calle)
	ancho_banqueta = c.get_value("calle", "ancho_banqueta", ancho_banqueta)
	alto_banqueta = c.get_value("calle", "alto_banqueta", alto_banqueta)
	_trazar(c.get_value("calle", "segmentos", []))

	# Las formas se agregan antes de meter el cuerpo a la escena: así la física lo arma una sola vez.
	_cuerpo = StaticBody3D.new()
	_cuerpo.name = "Colisiones"
	_construir_piso()
	_construir_calle(c.get_value("obstaculos", "baches", []))
	_construir_banquetas()
	_construir_topes(c.get_value("obstaculos", "topes", []), c.get_value("obstaculos", "alto_tope", 0.13), c.get_value("obstaculos", "radio_tope", 0.45))
	_construir_escenario(c.get_value("escenario", "semilla", 7), c.get_value("escenario", "separacion_edificios", 11.0))
	add_child(_cuerpo)
	_crear_multimallas()
	EstiloToon.aplicar(self)


# --- Consultas ------------------------------------------------------------

func derecha(i: int) -> Vector3:
	return direcciones[_ciclo(i)].cross(Vector3.UP)


## Índice de la muestra más cercana a `posicion`. Con `desde` busca solo cerca de esa muestra.
func indice_cercano(posicion: Vector3, desde: int = -1, ventana: int = 40) -> int:
	var mejor := 0
	var mejor_distancia := INF
	var inicio := 0
	var fin := puntos.size()
	if desde >= 0:
		inicio = desde - ventana
		fin = desde + ventana
	for k in range(inicio, fin):
		var i := _ciclo(k)
		var d := puntos[i].distance_squared_to(posicion)
		if d < mejor_distancia:
			mejor_distancia = d
			mejor = i
	return mejor


## Dónde poner el camión en la muestra `i`: carril 0 = derecho, 1 = izquierdo.
func transform_en_indice(i: int, carril: int = 0) -> Transform3D:
	i = _ciclo(i)
	var lado := 0.5 if carril == 0 else -0.5
	var origen := puntos[i] + derecha(i) * ancho_carril * lado + Vector3.UP * (alto_calle + 1.15)
	return Transform3D(Basis.looking_at(direcciones[i], Vector3.UP), origen)


func indice_en_distancia(distancia: float) -> int:
	return _ciclo(roundi(distancia / PASO))


func _ciclo(i: int) -> int:
	return posmod(i, puntos.size())


# --- Trazado --------------------------------------------------------------

func _trazar(segmentos: Array) -> void:
	var posicion := Vector3.ZERO
	var direccion := Vector3.FORWARD
	puntos.clear()
	direcciones.clear()
	puntos.append(posicion)
	direcciones.append(direccion)
	for segmento in segmentos:
		if segmento[0] == "recta":
			var pasos := maxi(1, roundi(segmento[1] / PASO))
			for _k in pasos:
				posicion += direccion * (segmento[1] / pasos)
				puntos.append(posicion)
				direcciones.append(direccion)
		elif segmento[0] == "curva":
			var radio: float = segmento[1]
			var angulo := deg_to_rad(segmento[2])
			var izquierda := Vector3.UP.cross(direccion)
			var centro := posicion + izquierda * radio * signf(angulo)
			var pasos := maxi(1, roundi(absf(angulo) * radio / PASO))
			var desde_centro := posicion - centro
			for k in range(1, pasos + 1):
				var giro := angulo * k / pasos
				puntos.append(centro + desde_centro.rotated(Vector3.UP, giro))
				direcciones.append(direccion.rotated(Vector3.UP, giro))
			posicion = puntos[puntos.size() - 1]
			direccion = direcciones[direcciones.size() - 1]
	# El circuito es cerrado: la última muestra coincide con la primera.
	if puntos.size() > 1 and puntos[puntos.size() - 1].distance_to(puntos[0]) < PASO * 0.5:
		puntos.remove_at(puntos.size() - 1)
		direcciones.remove_at(direcciones.size() - 1)
	longitud = puntos.size() * PASO


# --- Construcción ---------------------------------------------------------

func _construir_piso() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(800, 1, 800)
	_agregar_forma(forma, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	var malla := _malla_caja(Vector3(800, 1, 800), COLOR_PISO)
	malla.position = Vector3(0, -0.5, 0)
	malla.set_meta("sin_contorno", true)
	add_child(malla)


## Cada carril es una tira de cajas; donde hay bache se deja el hueco hasta el piso.
func _construir_calle(baches: Array) -> void:
	var n := puntos.size()
	for carril in 2:
		var lado := 0.5 if carril == 0 else -0.5
		var hueco: Array[bool] = []
		hueco.resize(n)
		hueco.fill(false)
		for bache in baches:
			if int(bache[1]) != carril:
				continue
			var desde := roundi(bache[0] / PASO)
			for k in maxi(1, roundi(bache[2] / PASO)):
				hueco[_ciclo(desde + k)] = true
			var centro := _desplazado(_ciclo(desde + roundi(bache[2] / PASO / 2.0)), ancho_carril * lado)
			var charco := _malla_caja(Vector3(ancho_carril * 0.8, 0.02, bache[2]), COLOR_BACHE)
			charco.transform = Transform3D(Basis.looking_at(direcciones[_ciclo(desde)], Vector3.UP), centro + Vector3.UP * 0.01)
			charco.set_meta("sin_contorno", true)
			add_child(charco)
		var i := 0
		while i < n:
			if hueco[i]:
				i += 1
				continue
			var j := i
			while j < n and j - i < 4 and not hueco[j]:
				j += 1
			_tira(i, j, ancho_carril * lado, ancho_carril, alto_calle, alto_calle, "asfalto", COLOR_ASFALTO)
			i = j
	# Raya central discontinua.
	for i in range(0, n, 4):
		var a := puntos[i]
		var b := puntos[_ciclo(i + 2)]
		_caja_visual("raya", COLOR_RAYA, (a + b) * 0.5 + Vector3.UP * (alto_calle + 0.01), b - a, Vector3(0.15, 0.02, a.distance_to(b)))


func _construir_banquetas() -> void:
	var n := puntos.size()
	var desplazamiento := ancho_carril + ancho_banqueta * 0.5
	var alto := alto_calle + alto_banqueta
	for i in range(0, n, 4):
		var j := mini(i + 4, n)
		for lado in [1.0, -1.0]:
			_tira(i, j, desplazamiento * lado, ancho_banqueta, alto, alto + alto_calle, "banqueta", COLOR_BANQUETA)
			_tira(i, j, (ancho_carril + 0.12) * lado, 0.24, alto + 0.005, 0.0, "guarnicion", COLOR_GUARNICION)


func _construir_topes(distancias: Array, alto_tope: float, radio: float) -> void:
	for distancia in distancias:
		var i := indice_en_distancia(distancia)
		var base := Basis(Vector3.UP, derecha(i), direcciones[i])
		var centro := puntos[i] + Vector3.UP * (alto_calle + alto_tope - radio)
		var forma := CylinderShape3D.new()
		forma.radius = radio
		forma.height = ancho_carril * 2.0
		_agregar_forma(forma, Transform3D(base, centro))
		var malla := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = radio
		cilindro.bottom_radius = radio
		cilindro.height = ancho_carril * 2.0
		cilindro.radial_segments = 16
		cilindro.material = _material(COLOR_TOPE)
		malla.mesh = cilindro
		malla.transform = Transform3D(base, centro)
		add_child(malla)


func _construir_escenario(semilla: int, separacion: float) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var n := puntos.size()
	var borde := ancho_carril + ancho_banqueta
	var paso := maxi(1, roundi(separacion / PASO))
	for i in range(0, n, paso):
		# Edificios por fuera del circuito, con tinaco en la azotea.
		var frente := azar.randf_range(7.0, 10.0)
		var fondo := azar.randf_range(6.0, 9.0)
		var alto := azar.randf_range(4.0, 13.0)
		var centro := _desplazado(i, borde + 1.0 + fondo * 0.5) + Vector3.UP * alto * 0.5
		var base := Basis.looking_at(direcciones[i], Vector3.UP)
		var color: Color = COLORES_FACHADA[azar.randi() % COLORES_FACHADA.size()]
		_solido(_malla_caja(Vector3(frente, alto, fondo), color), BoxShape3D.new(), Vector3(frente, alto, fondo), Transform3D(base, centro))
		if azar.randf() < 0.6:
			var tinaco := _malla_cilindro(0.55, 1.0, COLOR_TINACO)
			tinaco.position = centro + Vector3.UP * (alto * 0.5 + 0.5) + base.x * azar.randf_range(-2.0, 2.0)
			add_child(tinaco)
		# Árboles en la banqueta interior, de vez en cuando.
		if azar.randf() < 0.45:
			var pie := _desplazado(i, -(ancho_carril + ancho_banqueta * 0.5)) + Vector3.UP * (alto_calle + alto_banqueta)
			var tronco := _malla_cilindro(0.18, 2.4, COLOR_TRONCO)
			var forma := CylinderShape3D.new()
			forma.radius = 0.18
			forma.height = 2.4
			_solido(tronco, forma, Vector3.ZERO, Transform3D(Basis(), pie + Vector3.UP * 1.2))
			var copa := MeshInstance3D.new()
			var esfera := SphereMesh.new()
			esfera.radius = 1.3
			esfera.height = 2.4
			esfera.radial_segments = 10
			esfera.rings = 6
			esfera.material = _material(COLOR_FOLLAJE)
			copa.mesh = esfera
			copa.position = pie + Vector3.UP * 3.0
			add_child(copa)


# --- Utilidades -----------------------------------------------------------

func _desplazado(i: int, lateral: float) -> Vector3:
	return puntos[_ciclo(i)] + derecha(i) * lateral


## Caja con colisión entre las muestras i y j, desplazada a un lado del centro.
func _tira(i: int, j: int, lateral: float, ancho: float, alto_superior: float, grosor: float, grupo: String, color: Color) -> void:
	var a := _desplazado(i, lateral)
	var b := _desplazado(j, lateral)
	var largo := a.distance_to(b) + SOLAPE
	var centro := (a + b) * 0.5
	if grosor > 0.0:
		centro.y = alto_superior - grosor * 0.5
		var forma := BoxShape3D.new()
		forma.size = Vector3(ancho, grosor, largo)
		_agregar_forma(forma, Transform3D(Basis.looking_at(b - a, Vector3.UP), centro))
		_caja_visual(grupo, color, centro, b - a, Vector3(ancho, grosor, largo))
	else:
		centro.y = alto_superior
		_caja_visual(grupo, color, centro, b - a, Vector3(ancho, 0.01, largo))


func _agregar_forma(forma: Shape3D, donde: Transform3D) -> void:
	var nodo := CollisionShape3D.new()
	nodo.shape = forma
	nodo.transform = donde
	_cuerpo.add_child(nodo)


func _solido(malla: MeshInstance3D, forma: Shape3D, medidas: Vector3, donde: Transform3D) -> void:
	if forma is BoxShape3D:
		forma.size = medidas
	_agregar_forma(forma, donde)
	malla.transform = donde
	add_child(malla)


## Las piezas repetidas (calle, banqueta, rayas) se dibujan juntas con MultiMesh, sin contorno.
func _caja_visual(grupo: String, color: Color, centro: Vector3, direccion: Vector3, medidas: Vector3) -> void:
	if not _cajas_visuales.has(grupo):
		_cajas_visuales[grupo] = {"color": color, "transformaciones": []}
	var base := Basis.looking_at(direccion, Vector3.UP) * Basis.from_scale(medidas)
	_cajas_visuales[grupo].transformaciones.append(Transform3D(base, centro))


func _crear_multimallas() -> void:
	for grupo in _cajas_visuales:
		var datos: Dictionary = _cajas_visuales[grupo]
		var caja := BoxMesh.new()
		caja.material = _material(datos.color)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = caja
		multi.instance_count = datos.transformaciones.size()
		for k in multi.instance_count:
			multi.set_instance_transform(k, datos.transformaciones[k])
		var nodo := MultiMeshInstance3D.new()
		nodo.name = "Multimalla_" + grupo
		nodo.multimesh = multi
		nodo.material_override = EstiloToon.material(datos.color, false)
		add_child(nodo)


func _malla_caja(medidas: Vector3, color: Color) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = medidas
	caja.material = _material(color)
	malla.mesh = caja
	return malla


func _malla_cilindro(radio: float, alto: float, color: Color) -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radio
	cilindro.bottom_radius = radio
	cilindro.height = alto
	cilindro.radial_segments = 12
	cilindro.material = _material(color)
	malla.mesh = cilindro
	return malla


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
