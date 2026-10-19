class_name Calle
extends Node3D
## Calle por la que va el camión: dos carriles con baches, banquetas, topes, paradas, edificios
## y árboles. Se arma desde una `descripcion` (la ruta que hace GeneradorRuta, abierta y por zonas)
## o, si no se le da ninguna, desde config/calle_prueba.cfg (el circuito cerrado de prueba).
## También es la "línea de ruta": guarda una muestra por metro del centro de la calle, que usan
## el reinicio del camión, el piloto automático y los pasajeros.
##
## Descripción: {segmentos, topes, baches, paradas (distancias en m), cerrada, semilla,
##               zonas: [[desde_m, zona], ...]}.

const RUTA := "res://config/calle_prueba.cfg"
## Cómo se ve cada zona (DISEÑO.md, sección 4). En la etapa 7 se les da su identidad completa.
const ESTILOS := {
	"popular": {"colores": [Color(0.9, 0.3, 0.55), Color(0.98, 0.78, 0.3), Color(0.36, 0.76, 0.66), Color(0.95, 0.56, 0.2), Color(0.55, 0.8, 0.35)],
		"alto": [3.0, 7.0], "frente": [5.0, 8.0], "separacion": 8.0, "tinaco": 0.85, "arbol": 0.15, "hueco": 0.1},
	"centro": {"colores": [Color(0.85, 0.42, 0.3), Color(0.93, 0.85, 0.65), Color(0.75, 0.25, 0.22), Color(0.95, 0.72, 0.45)],
		"alto": [7.0, 12.0], "frente": [8.0, 11.0], "separacion": 10.0, "tinaco": 0.3, "arbol": 0.25, "hueco": 0.0},
	"lujo": {"colores": [Color(0.55, 0.7, 0.85), Color(0.85, 0.88, 0.9), Color(0.3, 0.38, 0.48), Color(0.75, 0.8, 0.82)],
		"alto": [16.0, 34.0], "frente": [12.0, 18.0], "separacion": 20.0, "tinaco": 0.0, "arbol": 0.8, "hueco": 0.15},
	"cruce": {"colores": [Color(0.6, 0.6, 0.62), Color(0.75, 0.7, 0.62), Color(0.5, 0.55, 0.6)],
		"alto": [3.0, 6.0], "frente": [10.0, 16.0], "separacion": 26.0, "tinaco": 0.2, "arbol": 0.1, "hueco": 0.55},
}
const ZONA_PRUEBA := "prueba"
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
const COLOR_POSTE := Color(0.2, 0.45, 0.85)
const COLOR_BANCA := Color(0.55, 0.35, 0.22)
## Dónde está la puerta del camión, medida desde su centro hacia adelante (m).
const PUERTA_ADELANTE := 3.15
const COLORES_FACHADA := [
	Color(0.9, 0.3, 0.55), Color(0.22, 0.38, 0.72), Color(0.98, 0.78, 0.3), Color(0.82, 0.42, 0.28),
	Color(0.36, 0.76, 0.66), Color(0.95, 0.56, 0.2), Color(0.93, 0.9, 0.84),
]

## Centro de la calle, una muestra por metro.
var puntos := PackedVector3Array()
## Dirección de avance en cada muestra.
var direcciones := PackedVector3Array()
var longitud: float = 0.0
## Paradas: cada una {indice_poste, indice_camion, poste (posición en la banqueta)}.
var paradas: Array[Dictionary] = []
## Si es un circuito cerrado (la calle de prueba) o una ruta con principio y fin.
var cerrada: bool = true
## Descripción con la que se armó (si viene de GeneradorRuta, se pone antes de agregarla a la escena).
var descripcion: Dictionary = {}
## Zona de cada muestra.
var zonas := PackedStringArray()

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
	var d := descripcion
	if d.is_empty():
		d = {
			"segmentos": c.get_value("calle", "segmentos", []),
			"topes": c.get_value("obstaculos", "topes", []),
			"baches": c.get_value("obstaculos", "baches", []),
			"paradas": c.get_value("paradas", "distancias", []),
			"cerrada": true,
			"semilla": c.get_value("escenario", "semilla", 7),
			"zonas": [[0.0, ZONA_PRUEBA]],
		}
	cerrada = d.get("cerrada", true)
	_trazar(d.segmentos)
	_asignar_zonas(d.get("zonas", [[0.0, ZONA_PRUEBA]]))

	# Las formas se agregan antes de meter el cuerpo a la escena: así la física lo arma una sola vez.
	_cuerpo = StaticBody3D.new()
	_cuerpo.name = "Colisiones"
	_construir_piso()
	_construir_calle(d.get("baches", []))
	_construir_banquetas()
	_construir_topes(d.get("topes", []), c.get_value("obstaculos", "alto_tope", 0.13), c.get_value("obstaculos", "radio_tope", 0.45))
	_construir_escenario(d.get("semilla", 7), c.get_value("escenario", "separacion_edificios", 11.0))
	_construir_paradas(d.get("paradas", []))
	if not cerrada:
		_construir_fin()
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


## Dónde queda el camión parado en la parada `k` (carril derecho).
func transform_parada(k: int) -> Transform3D:
	return transform_en_indice(paradas[k].indice_camion)


func indice_en_distancia(distancia: float) -> int:
	return _ciclo(roundi(distancia / PASO))


func zona_en(i: int) -> String:
	return zonas[_ciclo(i)] if not zonas.is_empty() else ZONA_PRUEBA


## En un circuito cerrado los índices dan la vuelta; en una ruta abierta se quedan en sus extremos.
func _ciclo(i: int) -> int:
	return posmod(i, puntos.size()) if cerrada else clampi(i, 0, puntos.size() - 1)


func _asignar_zonas(tramos: Array) -> void:
	zonas.resize(puntos.size())
	for i in puntos.size():
		var distancia := i * PASO
		var zona: String = tramos[0][1]
		for tramo in tramos:
			if distancia >= float(tramo[0]):
				zona = tramo[1]
		zonas[i] = zona


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
	# En un circuito cerrado la última muestra coincide con la primera.
	if cerrada and puntos.size() > 1 and puntos[puntos.size() - 1].distance_to(puntos[0]) < PASO * 0.5:
		puntos.remove_at(puntos.size() - 1)
		direcciones.remove_at(direcciones.size() - 1)
	longitud = puntos.size() * PASO


# --- Construcción ---------------------------------------------------------

func _construir_piso() -> void:
	# Piso que cubre toda la calle con 200 m de sobra alrededor.
	var limites := AABB(puntos[0], Vector3.ZERO)
	for p in puntos:
		limites = limites.expand(p)
	limites = limites.grow(200.0)
	var centro := limites.get_center()
	var medidas := Vector3(limites.size.x, 1.0, limites.size.z)
	var forma := BoxShape3D.new()
	forma.size = medidas
	_agregar_forma(forma, Transform3D(Basis(), Vector3(centro.x, -0.5, centro.z)))
	var malla := _malla_caja(medidas, COLOR_PISO)
	malla.position = Vector3(centro.x, -0.5, centro.z)
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
	for i in range(0, n - (0 if cerrada else 2), 4):
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
	if not cerrada:
		_construir_escenario_por_zonas(semilla)
		return
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
		# 2 m detrás de la banqueta: en el circuito se prueba a 90 km/h y el camión se abre en las curvas.
		var centro := _desplazado(i, borde + 2.0 + fondo * 0.5) + Vector3.UP * alto * 0.5
		var base := Basis.looking_at(direcciones[i], Vector3.UP)
		var color: Color = COLORES_FACHADA[azar.randi() % COLORES_FACHADA.size()]
		# Con looking_at, X es el lado hacia la calle (fondo) y Z va a lo largo de ella (frente).
		var invade := _invade_calle(i, base, centro, frente, fondo)
		if not invade:
			_solido(_malla_caja(Vector3(fondo, alto, frente), color), BoxShape3D.new(), Vector3(fondo, alto, frente), Transform3D(base, centro))
		if azar.randf() < 0.6 and not invade:
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


## Ruta abierta: edificios a los dos lados, con el estilo de la zona de cada tramo, y un letrero
## al entrar a cada zona.
func _construir_escenario_por_zonas(semilla: int) -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var borde := ancho_carril + ancho_banqueta
	var n := puntos.size()
	for lado in [1.0, -1.0]:
		var i := 0
		while i < n:
			var estilo: Dictionary = ESTILOS.get(zonas[i], ESTILOS["popular"])
			var frente := azar.randf_range(estilo.frente[0], estilo.frente[1])
			if azar.randf() >= float(estilo.hueco):
				var fondo := azar.randf_range(6.0, 10.0)
				var alto := azar.randf_range(estilo.alto[0], estilo.alto[1])
				var centro := _desplazado(i, (borde + 1.0 + fondo * 0.5) * lado) + Vector3.UP * alto * 0.5
				var base := Basis.looking_at(direcciones[i], Vector3.UP)
				var color: Color = estilo.colores[azar.randi() % estilo.colores.size()]
				# Del lado de adentro de una curva, las esquinas de un edificio largo se meten a la
				# calle: se prueba con la mitad del frente y, si aun así invade, no se pone.
				var ancho_edificio := frente * 0.92
				if _invade_calle(i, base, centro, ancho_edificio, fondo):
					ancho_edificio *= 0.5
				if not _invade_calle(i, base, centro, ancho_edificio, fondo):
					# Con looking_at, X es el lado hacia la calle (fondo) y Z va a lo largo de ella (frente).
					_solido(_malla_caja(Vector3(fondo, alto, ancho_edificio), color), BoxShape3D.new(), Vector3(fondo, alto, ancho_edificio), Transform3D(base, centro))
				var con_tinaco := azar.randf() < float(estilo.tinaco)
				var corrimiento := azar.randf_range(-2.0, 2.0)
				if con_tinaco and not _invade_calle(i, base, centro, ancho_edificio, fondo):
					var tinaco := _malla_cilindro(0.55, 1.0, COLOR_TINACO)
					tinaco.position = centro + Vector3.UP * (alto * 0.5 + 0.5) + base.x * corrimiento
					add_child(tinaco)
			if azar.randf() < float(estilo.arbol):
				_arbol(_desplazado(i, (ancho_carril + ancho_banqueta * 0.75) * lado) + Vector3.UP * (alto_calle + alto_banqueta))
			i += maxi(1, roundi(maxf(frente, float(estilo.separacion) * 0.5) / PASO))
	# Letrero al empezar cada zona, del lado izquierdo de la calle.
	var anterior := ""
	for i in range(0, n, 5):
		if zonas[i] == anterior:
			continue
		anterior = zonas[i]
		var letrero := Label3D.new()
		letrero.text = "ZONA_" + zonas[i].to_upper()
		letrero.pixel_size = 0.012
		letrero.font_size = 64
		letrero.outline_size = 16
		letrero.modulate = Color(1, 0.95, 0.6)
		letrero.outline_modulate = Color(0.12, 0.1, 0.1)
		letrero.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		letrero.position = _desplazado(i + 6, -(ancho_carril + 1.0)) + Vector3.UP * 4.5
		add_child(letrero)


## Si alguna esquina (o el punto medio de un lado) de la planta del edificio queda sobre la
## calle o la banqueta de cualquier tramo cercano.
func _invade_calle(i: int, base: Basis, centro: Vector3, frente: float, fondo: float) -> bool:
	var borde := ancho_carril + ancho_banqueta
	var ventana := roundi((frente + fondo) / PASO) + 10
	for x: float in [-0.5, 0.0, 0.5]:
		for z: float in [-0.5, 0.0, 0.5]:
			var punto := centro + base.x * fondo * x + base.z * frente * z
			var k := indice_cercano(punto, i, ventana)
			if Vector2(punto.x - puntos[k].x, punto.z - puntos[k].z).length() < borde:
				return true
	return false


func _arbol(pie: Vector3) -> void:
	var tronco := _malla_cilindro(0.18, 2.4, COLOR_TRONCO)
	_solido(tronco, _cilindro_forma(0.18, 2.4), Vector3.ZERO, Transform3D(Basis(), pie + Vector3.UP * 1.2))
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


## Ruta abierta: barrera al final, para que nada siga de largo.
func _construir_fin() -> void:
	var i := puntos.size() - 1
	var medidas := Vector3(ancho_carril * 2.0 + ancho_banqueta * 2.0, 1.2, 0.6)
	var centro := puntos[i] + direcciones[i] * 4.0 + Vector3.UP * (alto_calle + 0.6)
	_solido(_malla_caja(medidas, Color(0.95, 0.85, 0.2)), BoxShape3D.new(), medidas, Transform3D(Basis.looking_at(direcciones[i], Vector3.UP), centro))


func _construir_paradas(distancias: Array) -> void:
	paradas.clear()
	for distancia in distancias:
		var i := indice_en_distancia(distancia)
		var poste := _desplazado(i, ancho_carril + 0.6) + Vector3.UP * (alto_calle + alto_banqueta)
		paradas.append({
			"indice_poste": i,
			"indice_camion": _ciclo(i - roundi(PUERTA_ADELANTE / PASO)),
			"poste": poste,
		})
		var base := Basis.looking_at(-derecha(i), Vector3.UP)
		var tubo := _malla_cilindro(0.06, 2.6, COLOR_POSTE)
		_solido(tubo, _cilindro_forma(0.06, 2.6), Vector3.ZERO, Transform3D(base, poste + Vector3.UP * 1.3))
		var letrero := Label3D.new()
		letrero.text = "LETRERO_PARADA"
		letrero.pixel_size = 0.006
		letrero.font_size = 48
		letrero.outline_size = 12
		letrero.modulate = Color(1, 1, 1)
		letrero.outline_modulate = COLOR_POSTE.darkened(0.4)
		letrero.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		letrero.position = poste + Vector3.UP * 2.75
		add_child(letrero)
		var banca := _malla_caja(Vector3(1.6, 0.12, 0.45), COLOR_BANCA)
		var donde := _desplazado(i + 3, ancho_carril + ancho_banqueta - 0.35) + Vector3.UP * (alto_calle + alto_banqueta + 0.45)
		_solido(banca, BoxShape3D.new(), Vector3(1.6, 0.12, 0.45), Transform3D(Basis.looking_at(direcciones[i], Vector3.UP), donde))


## Pone un puesto de dulces en la banqueta, unos metros antes del poste de la parada k (para el
## vendedor, etapa 6A). Devuelve dónde se para el vendedor para reabastecer (del lado de la calle).
func poner_puesto_de_dulces(k: int) -> Vector3:
	var i: int = _ciclo(paradas[k].indice_poste - roundi(5.0 / PASO))
	var base := Basis.looking_at(-derecha(i), Vector3.UP)
	var piso := Vector3.UP * (alto_calle + alto_banqueta)
	var centro := _desplazado(i, ancho_carril + 1.4) + piso
	var mesa := Vector3(0.7, 0.9, 1.3)
	_solido(_malla_caja(mesa, Color(0.85, 0.3, 0.45)), BoxShape3D.new(), mesa, Transform3D(base, centro + Vector3.UP * mesa.y * 0.5))
	# Los dulces de colores encima de la mesa.
	for n in 4:
		var dulce := _malla_caja(Vector3(0.18, 0.12, 0.22), [Color(1.0, 0.8, 0.2), Color(0.3, 0.75, 0.95), Color(0.95, 0.4, 0.2), Color(0.5, 0.9, 0.4)][n])
		dulce.transform = Transform3D(base, centro + Vector3.UP * (mesa.y + 0.06) + base.x * (-0.45 + 0.3 * n))
		add_child(dulce)
	var palo := _malla_cilindro(0.03, 2.2, COLOR_TRONCO)
	palo.transform = Transform3D(base, centro + Vector3.UP * 1.1 + base.z * 0.25)
	add_child(palo)
	var sombrilla := _malla_cilindro(1.0, 0.12, Color(1.0, 0.85, 0.3))
	sombrilla.transform = Transform3D(base, centro + Vector3.UP * 2.2)
	add_child(sombrilla)
	var letrero := Label3D.new()
	letrero.text = "LETRERO_DULCES"
	letrero.pixel_size = 0.005
	letrero.font_size = 48
	letrero.outline_size = 12
	letrero.modulate = Color(1, 0.95, 0.5)
	letrero.outline_modulate = Color(0.4, 0.1, 0.2)
	letrero.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	letrero.position = centro + Vector3.UP * 2.6
	add_child(letrero)
	return _desplazado(i, ancho_carril + 0.6) + piso


func _cilindro_forma(radio: float, alto: float) -> CylinderShape3D:
	var forma := CylinderShape3D.new()
	forma.radius = radio
	forma.height = alto
	return forma


# --- Utilidades -----------------------------------------------------------

func _desplazado(i: int, lateral: float) -> Vector3:
	return puntos[_ciclo(i)] + derecha(i) * lateral


## Caja con colisión entre las muestras i y j, desplazada a un lado del centro.
func _tira(i: int, j: int, lateral: float, ancho: float, alto_superior: float, grosor: float, grupo: String, color: Color) -> void:
	var a := _desplazado(i, lateral)
	var b := _desplazado(j, lateral)
	if a.distance_to(b) < 0.01:
		return
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
