class_name Personaje
extends Node3D
## Figura visual de un personaje: una malla con esqueleto (modelos/personajes/<modelo>.glb, la arma
## Blender con scripts/herramientas/esqueleto_blender.py) que se anima en código: caminar,
## sujetarse, cargar, tropezar, sentarse y ladearse con los empujones. La piel es continua, así que
## al doblar una rodilla o un codo se dobla en lugar de partirse (D52). No tiene física; la lógica
## vive en CuerpoPersonaje y aquí solo se dibuja. Origen entre los pies, mirando a -Z.
##
## Encima de la animación va un "ragdoll ligero": la mano que se sujeta alcanza la agarradera de
## verdad, los pies no se hunden en el piso (ni flotan al estar parado), sentado la cadera queda
## sobre el asiento, y el cuerpo se mece como un resorte con los empujones y se recupera solo.
##
## Los modelos con rig de Tripo también tienen animaciones hechas (susto, asentir, enojo, pelear;
## AnimacionesPersonaje) que se mezclan encima con `reproducir` (D53).
##
## Huesos: Cadera (raíz) > Torso > Cabeza, Brazo > Antebrazo; Cadera > Pierna > Pantorrilla
## (Izquierdo/Derecho). Las rotaciones de la animación van en los ejes de la figura (x: a su
## derecha, y: arriba, z: hacia atrás), alrededor de la articulación de cada hueso.

const CARPETA := "res://modelos/personajes"
const HUESOS := ["Cadera", "Torso", "Cabeza", "BrazoIzquierdo", "AntebrazoIzquierdo", "BrazoDerecho", "AntebrazoDerecho", "PiernaIzquierda", "PantorrillaIzquierda", "PiernaDerecha", "PantorrillaDerecha"]

## Mallas con la normal suavizada para el contorno, ya calculadas (una por malla del modelo).
static var _mallas_contorno: Dictionary = {}
## Cajas de cada hueso por modelo (lo que ocupa su parte de la malla), para el ragdoll.
static var _cajas_por_modelo: Dictionary = {}

@export var modelo: String = "cobrador":
	set(valor):
		modelo = valor
		if is_inside_tree():
			_cargar()

var altura: float = 1.7
var altura_ojos: float = 1.55
var ancho: float = 0.8
## Altura de la cadera (donde se unen las piernas): para sentarlo a la altura del asiento.
var altura_cadera: float = 0.8
## Mano derecha en coordenadas de este nodo (para colocar lo que carga).
var mano_derecha := Vector3(0.3, 0.9, 0.0)
## Dónde se agarra la mano al sujetarse, en coordenadas de este nodo (Vector3.INF: en ningún lado).
var agarre := Vector3.INF
## Altura del asiento sobre el piso: sentado, el piso queda a altura_cadera - altura_asiento.
var altura_asiento: float = 0.45

var _figura: Node3D
var _esqueleto: Skeleton3D
var _malla: MeshInstance3D
## Del esqueleto a la figura (el .glb puede traer un nodo encima).
var _en_figura := Transform3D()
## nombre -> índice del hueso.
var _huesos: Dictionary = {}
## índice -> reposo del hueso en la figura (su articulación y sus ejes).
var _reposo: Dictionary = {}
## nombre -> giro actual (euler, ejes de la figura), suavizado.
var _giros: Dictionary = {}
var _cabeza_oculta: bool = false
var _fase: float = 0.0
var _inclinacion := Vector3.ZERO
## Qué tanto está caminando (0 a 1), suavizado: los pasos empiezan y terminan sin brincos.
var _paso: float = 0.0
## Reloj para la respiración y el peso en reposo (cada quien empieza en otro punto).
var _reloj: float = randf() * TAU
## Cara animada (CaraPersonaje), si el modelo la tiene: boca y párpados.
var _cara: Dictionary = {}
var _hablando: float = 0.0
var _gritando: bool = false
var _boca: float = 0.0
var _para_parpadear: float = randf_range(1.0, 4.0)
var _parpadeo: float = -1.0
## Para alcanzar con manos y pies: la punta de la mano (en el hueso del antebrazo) y la planta del
## pie (en el de la pantorrilla), por lado, y a qué altura queda la planta en reposo.
var _mano_local: Dictionary = {}
var _planta_local: Dictionary = {}
var _altura_planta: Dictionary = {}
## Lo que hay de la articulación de la cadera a la parte de atrás del muslo (sentado, al asiento).
var _grosor_muslo: float = 0.0
## Qué tanto va la mano a la agarradera (0 a 1, para que llegue y se suelte suave), con cuál mano y
## a qué punto.
var _peso_agarre: float = 0.0
var _lado_agarre: String = "Derecho"
var _ultimo_agarre := Vector3.INF
## Velocidad del ladeo (el resorte de los empujones).
var _vel_inclinacion := Vector3.ZERO

## Animación hecha que se está reproduciendo (AnimacionesPersonaje): su nombre, datos, tiempo, qué
## tanto manda (0 a 1, para entrar y salir suave) y cuánto sube o baja la cadera. Sentado solo se
## mueve de la cintura para arriba. `_descanso`: tiempo antes de poder repetir la misma.
var _con_animaciones: bool = false
var _clip_nombre: String = ""
var _clip: Dictionary = {}
var _clip_t: float = 0.0
var _clip_peso: float = 0.0
var _clip_subida: float = 0.0
var _ultimo_clip: String = ""
var _descanso: float = 0.0
## Del clip a cada personaje: el giro de la pose T a su reposo, por hueso de brazos y piernas.
var _de_t: Dictionary = {}
const PADRE_HUESO := {
	"Torso": "Cadera", "Cabeza": "Torso", "BrazoIzquierdo": "Torso", "BrazoDerecho": "Torso",
	"AntebrazoIzquierdo": "BrazoIzquierdo", "AntebrazoDerecho": "BrazoDerecho",
	"PiernaIzquierda": "Cadera", "PiernaDerecha": "Cadera",
	"PantorrillaIzquierda": "PiernaIzquierda", "PantorrillaDerecha": "PiernaDerecha",
}
const DE_CINTURA_ABAJO := ["Cadera", "PiernaIzquierda", "PiernaDerecha", "PantorrillaIzquierda", "PantorrillaDerecha"]

## El resorte del ladeo: rigidez y amortiguamiento (por debajo del crítico: se pasa un poco y regresa).
const RIGIDEZ_LADEO := 45.0
const AMORTIGUA_LADEO := 6.0


func _ready() -> void:
	_cargar()


func _cargar() -> void:
	if _figura != null:
		_figura.queue_free()
	var escena := load(CARPETA.path_join(modelo + ".glb")) as PackedScene
	if escena == null:
		push_error("No existe el personaje: " + modelo)
		return
	var importado: Node3D = escena.instantiate()
	var esqueletos := importado.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		push_error("El personaje %s no tiene esqueleto (falta procesarlo con procesar_personajes.bat)" % modelo)
		importado.free()
		return
	_figura = Node3D.new()
	_figura.name = "Figura"
	add_child(_figura)
	# Se toma solo el esqueleto (con su malla), con su lugar relativo al modelo.
	_esqueleto = esqueletos[0]
	_en_figura = _relativa_a(_esqueleto, importado)
	_esqueleto.owner = null
	_esqueleto.get_parent().remove_child(_esqueleto)
	_esqueleto.name = "Esqueleto"
	_esqueleto.transform = _en_figura
	_figura.add_child(_esqueleto)
	importado.free()
	for hijo in _esqueleto.get_children():
		hijo.owner = null
		if hijo is MeshInstance3D and _malla == null:
			_malla = hijo
	_malla.mesh = _malla_con_contorno(_malla.mesh)
	_huesos.clear()
	_reposo.clear()
	_giros.clear()
	for nombre in HUESOS:
		var i := _esqueleto.find_bone(nombre)
		if i >= 0:
			_huesos[nombre] = i
			_reposo[i] = _en_figura * _esqueleto.get_bone_global_rest(i)
	EstiloToon.aplicar(_figura)
	_cara = CaraPersonaje.armar(modelo, _malla, _esqueleto, _en_figura)
	_medir()
	_con_animaciones = AnimacionesPersonaje.tiene_rig(modelo)
	_de_t.clear()


## Estatura, ancho, cuello, cadera y mano, sacados de la malla y del esqueleto.
func _medir() -> void:
	var caja := _en_figura * _malla.transform * _malla.get_aabb()
	altura = caja.end.y
	ancho = caja.size.x
	var cuello := altura * 0.7
	if _huesos.has("Cabeza"):
		cuello = (_reposo[_huesos["Cabeza"]] as Transform3D).origin.y
	altura_ojos = cuello + (altura - cuello) * 0.45
	if _huesos.has("PiernaIzquierda"):
		altura_cadera = (_reposo[_huesos["PiernaIzquierda"]] as Transform3D).origin.y
	var cajas := cajas_de_huesos()
	if cajas.has("AntebrazoDerecho"):
		# La mano es la punta del antebrazo (a lo largo del hueso, su eje Y).
		var suya: AABB = cajas["AntebrazoDerecho"]
		var c := suya.get_center()
		mano_derecha = (_reposo[_huesos["AntebrazoDerecho"]] as Transform3D) * Vector3(c.x, suya.end.y * 0.92, c.z)
	_mano_local.clear()
	_planta_local.clear()
	_altura_planta.clear()
	for lado in ["Izquierdo", "Derecho"]:
		if cajas.has("Antebrazo" + lado):
			var suya: AABB = cajas["Antebrazo" + lado]
			_mano_local[lado] = Vector3(suya.get_center().x, suya.end.y * 0.92, suya.get_center().z)
	var grosores := []
	for lado in ["Izquierda", "Derecha"]:
		if cajas.has("Pantorrilla" + lado):
			var suya: AABB = cajas["Pantorrilla" + lado]
			var planta := Vector3(suya.get_center().x, suya.end.y, suya.get_center().z)
			_planta_local[lado] = planta
			_altura_planta[lado] = ((_reposo[_huesos["Pantorrilla" + lado]] as Transform3D) * planta).y
		if cajas.has("Pierna" + lado):
			# Lo más atrás del muslo, en los ejes del hueso: sentado, eso es lo que va abajo.
			var suya: AABB = cajas["Pierna" + lado]
			var atras := (_reposo[_huesos["Pierna" + lado]] as Transform3D).basis.orthonormalized().inverse() * Vector3.BACK
			var lo_mas := 0.0
			for k in 8:
				lo_mas = maxf(lo_mas, suya.get_endpoint(k).dot(atras))
			grosores.append(lo_mas)
	var suma := 0.0
	for g in grosores:
		suma += g
	_grosor_muslo = clampf(suma / maxf(grosores.size(), 1) * 0.8, 0.0, 0.2)


static func _relativa_a(nodo: Node3D, raiz: Node3D) -> Transform3D:
	var t := nodo.transform
	var padre := nodo.get_parent()
	while padre != null and padre != raiz:
		if padre is Node3D:
			t = (padre as Node3D).transform * t
		padre = padre.get_parent()
	return t


## Copia de la malla con una normal suavizada (promedio de los vértices en la misma posición)
## guardada en el color de vértice: la usa el contorno para no abrirse en las costuras de la
## textura. Conserva la piel (huesos y pesos) y las claves de forma. Una vez por malla.
static func _malla_con_contorno(malla: Mesh) -> Mesh:
	if malla == null or not malla is ArrayMesh:
		return malla
	var clave := malla.get_instance_id()
	if _mallas_contorno.has(clave):
		return _mallas_contorno[clave]
	var nueva := ArrayMesh.new()
	nueva.blend_shape_mode = malla.blend_shape_mode
	for b in malla.get_blend_shape_count():
		nueva.add_blend_shape(malla.get_blend_shape_name(b))
	for s in malla.get_surface_count():
		var arreglos := malla.surface_get_arrays(s)
		var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
		var normales: PackedVector3Array = arreglos[Mesh.ARRAY_NORMAL]
		var suma := {}
		for k in vertices.size():
			var punto := Vector3i((vertices[k] * 2000.0).round())
			suma[punto] = (suma.get(punto, Vector3.ZERO) as Vector3) + normales[k]
		var suaves := PackedColorArray()
		suaves.resize(vertices.size())
		for k in vertices.size():
			var n: Vector3 = (suma[Vector3i((vertices[k] * 2000.0).round())] as Vector3).normalized()
			suaves[k] = Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5)
		arreglos[Mesh.ARRAY_COLOR] = suaves
		nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos, malla.surface_get_blend_shape_arrays(s))
		nueva.surface_set_material(s, malla.surface_get_material(s))
	_mallas_contorno[clave] = nueva
	return nueva


## Lo que ocupa cada hueso: la caja de los vértices que mueve sobre todo él, en los ejes del hueso
## (su eje Y va a lo largo del miembro). Una vez por modelo.
func cajas_de_huesos() -> Dictionary:
	if _cajas_por_modelo.has(modelo):
		return _cajas_por_modelo[modelo]
	var cajas := {}
	var arreglos := _malla.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arreglos[Mesh.ARRAY_VERTEX]
	var indices_huesos: PackedInt32Array = arreglos[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arreglos[Mesh.ARRAY_WEIGHTS]
	var por_vertice := indices_huesos.size() / maxi(vertices.size(), 1)
	# Los índices de la piel son de sus "binds": se pasan a huesos del esqueleto.
	var piel := _malla.skin
	var hueso_de_bind := {}
	for b in piel.get_bind_count():
		var nombre := String(piel.get_bind_name(b))
		hueso_de_bind[b] = _esqueleto.find_bone(nombre) if nombre != "" else piel.get_bind_bone(b)
	var inversa := {}
	for i in _reposo:
		inversa[i] = _esqueleto.get_bone_global_rest(i).affine_inverse()
	for v in vertices.size():
		var mejor := -1
		var mejor_peso := 0.0
		for k in por_vertice:
			var w := pesos[v * por_vertice + k]
			if w > mejor_peso:
				mejor_peso = w
				mejor = hueso_de_bind.get(indices_huesos[v * por_vertice + k], -1)
		if not inversa.has(mejor):
			continue
		var p: Vector3 = inversa[mejor] * (_malla.transform * vertices[v])
		var nombre := _esqueleto.get_bone_name(mejor)
		cajas[nombre] = AABB(p, Vector3.ZERO) if not cajas.has(nombre) else (cajas[nombre] as AABB).expand(p)
	_cajas_por_modelo[modelo] = cajas
	return cajas


## Para el ragdoll: cada hueso con su pose actual respecto a este nodo y su caja (en sus ejes):
## [[nombre, Transform3D, AABB], ...]. Sin la Cadera, que no mueve vértices.
func huesos_para_ragdoll() -> Array:
	var lista := []
	var cajas := cajas_de_huesos()
	for nombre in _huesos:
		if not cajas.has(nombre):
			continue
		var i: int = _huesos[nombre]
		lista.append([nombre, _figura.transform * _en_figura * _esqueleto.get_bone_global_pose(i), cajas[nombre]])
	return lista


## Para el ragdoll: una copia del esqueleto con su malla (y la cara como está), que el ragdoll
## mueve hueso por hueso. Se cuelga donde va el Torso; devuelve también su lugar relativo a él.
func copia_para_ragdoll() -> Array:
	var copia: Skeleton3D = _esqueleto.duplicate()
	for b in _malla.mesh.get_blend_shape_count():
		var malla_copia: MeshInstance3D = copia.get_node(NodePath(_malla.name))
		malla_copia.set_blend_shape_value(b, _malla.get_blend_shape_value(b))
	var torso: Transform3D = _figura.transform * _en_figura * _esqueleto.get_bone_global_pose(_huesos["Torso"])
	return [copia, torso.affine_inverse() * _figura.transform * _en_figura, _cabeza_oculta]


## Muestra u oculta toda la figura (mientras el personaje anda hecho ragdoll).
func mostrar(visible_figura: bool) -> void:
	if _figura != null:
		_figura.visible = visible_figura


## Mueve la boca como si hablara durante `segundos` (si el modelo tiene cara animada).
func hablar(segundos: float) -> void:
	_hablando = maxf(_hablando, segundos)


## Boca abierta de par en par mientras grita (el voceador).
func gritar(si: bool) -> void:
	_gritando = si


## Oculta la cabeza (para la cámara en primera persona del propio jugador): el hueso se encoge.
func ocultar_cabeza(ocultar: bool) -> void:
	_cabeza_oculta = ocultar
	if _huesos.has("Cabeza"):
		_esqueleto.set_bone_pose_scale(_huesos["Cabeza"], Vector3.ONE * (0.001 if ocultar else 1.0))


## Actualiza la pose. `velocidad` y `empujon` van en coordenadas de este nodo.
func animar(delta: float, velocidad: Vector3, empujon: Vector3, sujetado: bool, cargando: bool, tropezando: bool, en_el_aire: bool, sentado: bool = false, manejando: bool = false) -> void:
	if _huesos.is_empty():
		return
	var rapidez := Vector2(velocidad.x, velocidad.z).length()
	# El ritmo sigue a la velocidad: un ciclo (dos pasos) cada dos zancadas, así los pies no patinan.
	var zancada := maxf(altura * 0.42, 0.3)
	_paso = lerpf(_paso, clampf(rapidez / 2.2, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	_fase = wrapf(_fase + delta * PI * rapidez / zancada, 0.0, TAU)
	_reloj = wrapf(_reloj + delta * 1.7, 0.0, TAU)
	var amplitud := deg_to_rad(18.0 + 12.0 * _paso) * _paso
	var balanceo := sin(_fase) * amplitud
	# Caminando de lado o hacia atrás se balancea menos.
	var de_frente := absf(velocidad.z) / maxf(rapidez, 0.001)
	balanceo *= lerpf(0.6, 1.0, de_frente)

	var pierna_izq := balanceo
	var pierna_der := -balanceo
	# Rodillas (negativo: el pie va hacia atrás). Al caminar se dobla la que va en el aire, que es la
	# que pasa de atrás hacia adelante.
	var rodilla_izq := -maxf(0.0, cos(_fase)) * amplitud * 1.3
	var rodilla_der := -maxf(0.0, -cos(_fase)) * amplitud * 1.3
	# Brazos al revés de las piernas, un poco abiertos; en reposo cuelgan respirando.
	var respiro := sin(_reloj) * (1.0 - _paso)
	var abrir := deg_to_rad(4.0 + 2.0 * respiro)
	var brazo_izq := Vector3(-balanceo * 0.9, 0.0, -abrir)
	var brazo_der := Vector3(balanceo * 0.9, 0.0, abrir)
	# Codos (positivo: la mano va hacia el frente). Un poco doblados siempre, más al caminar.
	var codo_izq := deg_to_rad(8.0 + 14.0 * _paso) + maxf(0.0, -balanceo) * 0.6
	var codo_der := deg_to_rad(8.0 + 14.0 * _paso) + maxf(0.0, balanceo) * 0.6
	var cabeza := Vector3(deg_to_rad(1.5) * respiro, -balanceo * 0.15, 0.0)
	# Los hombros giran contra la cadera y la cabeza sigue viendo al frente.
	var torso := Vector3(0.0, balanceo * 0.15, 0.0)
	# Con las piernas abiertas la cadera baja: el cuerpo sube y baja al caminar, y se mece hacia la
	# pierna que apoya.
	var rebote := -altura_cadera * (1.0 - cos(balanceo)) * 0.6 + 0.004 * respiro
	var meneo := cos(_fase) * deg_to_rad(3.0) * _paso
	# Caminando se echa un poco hacia adelante.
	var adelante := -deg_to_rad(4.0) * _paso
	var andando := true

	if en_el_aire:
		andando = false
		pierna_izq = deg_to_rad(-25.0)
		pierna_der = deg_to_rad(15.0)
		rodilla_izq = deg_to_rad(-35.0)
		rodilla_der = deg_to_rad(-15.0)
		brazo_izq = Vector3(0.0, 0.0, deg_to_rad(-60.0))
		brazo_der = Vector3(0.0, 0.0, deg_to_rad(60.0))
		codo_izq = deg_to_rad(30.0)
		codo_der = deg_to_rad(30.0)
	if tropezando:
		# Aspavientos: brazos girando y piernas trastabillando.
		andando = false
		var agitar := sin(_reloj * 6.0)
		brazo_izq = Vector3(deg_to_rad(100.0 + 60.0 * agitar), 0.0, deg_to_rad(-40.0))
		brazo_der = Vector3(deg_to_rad(100.0 - 60.0 * agitar), 0.0, deg_to_rad(40.0))
		codo_izq = deg_to_rad(40.0 + 30.0 * agitar)
		codo_der = deg_to_rad(40.0 - 30.0 * agitar)
		pierna_izq = deg_to_rad(25.0) * agitar
		pierna_der = -pierna_izq
		rodilla_izq = deg_to_rad(-30.0) * maxf(0.0, agitar)
		rodilla_der = deg_to_rad(-30.0) * maxf(0.0, -agitar)
		cabeza = Vector3(deg_to_rad(15.0) * agitar, 0.0, 0.0)
	if cargando:
		brazo_izq = Vector3(deg_to_rad(55.0), 0.0, deg_to_rad(10.0))
		brazo_der = Vector3(deg_to_rad(55.0), 0.0, deg_to_rad(-10.0))
		codo_izq = deg_to_rad(45.0)
		codo_der = deg_to_rad(45.0)
	if sentado:
		# Muslos al frente y pantorrillas hacia abajo, como en una silla; manos sobre las rodillas.
		andando = false
		pierna_izq = deg_to_rad(85.0)
		pierna_der = deg_to_rad(85.0)
		rodilla_izq = deg_to_rad(-85.0)
		rodilla_der = deg_to_rad(-85.0)
		brazo_izq = Vector3(deg_to_rad(20.0), 0.0, 0.0)
		brazo_der = Vector3(deg_to_rad(20.0), 0.0, 0.0)
		codo_izq = deg_to_rad(55.0)
		codo_der = deg_to_rad(55.0)
	if manejando:
		# Las dos manos al volante, que se mueve con la vuelta (empujon.x trae el volante).
		andando = false
		brazo_izq = Vector3(deg_to_rad(45.0 + 12.0 * empujon.x), 0.0, deg_to_rad(12.0))
		brazo_der = Vector3(deg_to_rad(45.0 - 12.0 * empujon.x), 0.0, deg_to_rad(-12.0))
		codo_izq = deg_to_rad(45.0)
		codo_der = deg_to_rad(45.0)
	if sujetado:
		# Un brazo arriba, agarrado del pasamanos o del respaldo, abierto hacia afuera para que no
		# pase por enfrente de la cara: el del lado de la agarradera (si carga algo, el izquierdo).
		# Luego la mano alcanza el punto exacto (_alcanzar).
		var izquierdo := cargando or (agarre.is_finite() and agarre.x < -0.05)
		_lado_agarre = "Izquierdo" if izquierdo else "Derecho"
		if izquierdo:
			brazo_izq = Vector3(deg_to_rad(165.0), 0.0, deg_to_rad(-25.0))
			codo_izq = deg_to_rad(10.0)
		else:
			brazo_der = Vector3(deg_to_rad(165.0), 0.0, deg_to_rad(25.0))
			codo_der = deg_to_rad(10.0)

	# Todo el cuerpo se ladea hacia donde lo empuja el camión (frente = -Z), como un resorte: los
	# golpes (sacudir) le dan velocidad y regresa solo. La cabeza se queda un poco atrás y, sin
	# agarrarse, los brazos se abren para no caerse.
	var objetivo := Vector3(empujon.z, 0.0, -empujon.x) * deg_to_rad(2.2)
	objetivo = objetivo.limit_length(deg_to_rad(25.0))
	_vel_inclinacion += ((objetivo - _inclinacion) * RIGIDEZ_LADEO - _vel_inclinacion * AMORTIGUA_LADEO) * delta
	_inclinacion = (_inclinacion + _vel_inclinacion * delta).limit_length(deg_to_rad(35.0))
	cabeza -= Vector3(_vel_inclinacion.x, 0.0, _vel_inclinacion.z) * 0.08
	if not (sujetado or cargando or sentado or manejando or tropezando):
		var desequilibrio := clampf(_inclinacion.length() / deg_to_rad(20.0), 0.0, 1.0)
		brazo_izq.z -= desequilibrio * deg_to_rad(45.0)
		brazo_der.z += desequilibrio * deg_to_rad(45.0)

	var t := 1.0 - exp(-14.0 * delta)
	_girar("PiernaIzquierda", Vector3(pierna_izq, 0.0, 0.0), t)
	_girar("PiernaDerecha", Vector3(pierna_der, 0.0, 0.0), t)
	_girar("PantorrillaIzquierda", Vector3(rodilla_izq, 0.0, 0.0), t)
	_girar("PantorrillaDerecha", Vector3(rodilla_der, 0.0, 0.0), t)
	_girar("BrazoIzquierdo", brazo_izq, t)
	_girar("BrazoDerecho", brazo_der, t)
	_girar("AntebrazoIzquierdo", Vector3(codo_izq, 0.0, 0.0), t)
	_girar("AntebrazoDerecho", Vector3(codo_der, 0.0, 0.0), t)
	_girar("Cabeza", cabeza, t)
	_girar("Torso", torso if andando else Vector3.ZERO, t)
	_aplicar_clip(delta, sentado)

	if not andando:
		rebote = 0.0
		meneo = 0.0
		adelante = 0.0
	if sentado:
		# La cadera sobre el asiento, no hundida: se sube lo que mide el muslo por detrás.
		rebote = _grosor_muslo
	rebote += _clip_subida
	_figura.rotation = Vector3(_inclinacion.x + adelante, 0.0, _inclinacion.z + meneo)
	_figura.position.y = lerpf(_figura.position.y, rebote, t)
	_alcanzar(delta, sujetado, sentado, en_el_aire, tropezando)
	_animar_cara(delta, tropezando or en_el_aire)


## Reproduce una animación hecha (si el modelo las tiene): "susto", "asentir", "enojo" o "pelear".
## Devuelve si empezó. No interrumpe la que va ni repite la misma enseguida.
func reproducir(nombre: String) -> bool:
	if not _con_animaciones or _clip_nombre != "" or (nombre == _ultimo_clip and _descanso > 0.0):
		return false
	var datos := AnimacionesPersonaje.clip(nombre)
	if datos.is_empty() or int(datos.cuadros) < 2:
		return false
	_clip_nombre = nombre
	_clip = datos
	_clip_t = 0.0
	_ultimo_clip = nombre
	return true


## Qué animación hecha se está reproduciendo ("" si ninguna).
func animacion_actual() -> String:
	return _clip_nombre


## Mezcla la animación hecha encima de la pose: entra y sale suave. Cada hueso toma el giro del
## clip respecto a la pose T, corregido por el reposo de este personaje (los brazos caídos).
func _aplicar_clip(delta: float, sentado: bool) -> void:
	_descanso = maxf(0.0, _descanso - delta)
	if _huesos.has("Cadera"):
		# La Cadera no la mueve la animación de código: vuelve a su reposo en cada cuadro.
		var i_cadera: int = _huesos["Cadera"]
		_esqueleto.set_bone_pose_rotation(i_cadera, _esqueleto.get_bone_rest(i_cadera).basis.get_rotation_quaternion())
	if _clip_nombre == "":
		_clip_subida = 0.0
		return
	var fps: float = _clip.fps
	var cuadros: int = _clip.cuadros
	var duracion := (cuadros - 1) / fps
	_clip_t += delta
	if _clip_t >= duracion:
		_clip_peso = move_toward(_clip_peso, 0.0, delta * 4.0)
		if _clip_peso <= 0.0:
			_clip_nombre = ""
			_clip = {}
			_clip_subida = 0.0
			_descanso = 3.0
			return
	else:
		_clip_peso = move_toward(_clip_peso, 1.0, delta * 5.0)
	var posicion := clampf(_clip_t * fps, 0.0, cuadros - 1.0)
	var k := mini(int(posicion), cuadros - 2)
	var fraccion := posicion - k
	var peso := smoothstep(0.0, 1.0, _clip_peso)
	var giros := {}
	for nombre in HUESOS:
		if not _huesos.has(nombre) or not (_clip.huesos as Dictionary).has(nombre):
			continue
		var lista: Array = _clip.huesos[nombre]
		var giro: Quaternion = (lista[k] as Quaternion).slerp(lista[k + 1], fraccion)
		if sentado and nombre in DE_CINTURA_ABAJO:
			giro = Quaternion.IDENTITY
		var i: int = _huesos[nombre]
		var reposo: Basis = (_reposo[i] as Transform3D).basis.orthonormalized()
		# Brazos y piernas: el clip gira desde la pose T; este personaje está en su reposo.
		if (_clip.en_t as Dictionary).has(nombre) and nombre != "Cadera" and nombre != "Torso" and nombre != "Cabeza":
			if not _de_t.has(nombre):
				var en_t: Vector3 = _clip.en_t[nombre]
				_de_t[nombre] = Quaternion(en_t.normalized(), (reposo * Vector3.UP).normalized())
			giro = giro * (_de_t[nombre] as Quaternion).inverse()
		giros[nombre] = giro
		var del_padre: Quaternion = giros.get(PADRE_HUESO.get(nombre, ""), Quaternion.IDENTITY)
		var propio := Basis(del_padre.inverse() * giro)
		var local := (_esqueleto.get_bone_rest(i).basis.orthonormalized() * (reposo.inverse() * propio * reposo)).get_rotation_quaternion()
		_esqueleto.set_bone_pose_rotation(i, _esqueleto.get_bone_pose_rotation(i).slerp(local, peso))
	var subidas: Array = _clip.cadera_y
	_clip_subida = 0.0 if sentado else lerpf(float(subidas[k]), float(subidas[k + 1]), fraccion) * altura * peso


## Un golpe directo (`golpe`: cambio de velocidad en m/s, en coordenadas de este nodo): el cuerpo se
## mece hacia allá y regresa solo.
func sacudir(golpe: Vector3) -> void:
	_vel_inclinacion += Vector3(golpe.z, 0.0, -golpe.x) * 0.5
	_vel_inclinacion = _vel_inclinacion.limit_length(4.0)


## Sobre la pose de la animación: la mano que se sujeta va a la agarradera y los pies no se hunden en
## el piso (parado, tampoco flotan; sentado, si la pierna no cabe, sube la rodilla).
func _alcanzar(delta: float, sujetado: bool, sentado: bool, en_el_aire: bool, tropezando: bool) -> void:
	var de_esqueleto := _figura.transform * _esqueleto.transform
	var a_esqueleto := de_esqueleto.affine_inverse()
	var quiere := sujetado and agarre.is_finite()
	if quiere:
		_ultimo_agarre = agarre
	_peso_agarre = move_toward(_peso_agarre, 1.0 if quiere else 0.0, delta * 5.0)
	if _peso_agarre > 0.0 and _ultimo_agarre.is_finite() and _mano_local.has(_lado_agarre):
		var hacia_afuera := 1.0 if _lado_agarre == "Derecho" else -1.0
		# El codo hacia afuera y abajo.
		_dos_huesos("Brazo" + _lado_agarre, "Antebrazo" + _lado_agarre, _mano_local[_lado_agarre], a_esqueleto * _ultimo_agarre,
			a_esqueleto.basis * Vector3(hacia_afuera * 0.7, -1.0, 0.3), smoothstep(0.0, 1.0, _peso_agarre))
	if en_el_aire:
		return
	var piso := altura_cadera - altura_asiento if sentado else 0.0
	for lado in ["Izquierda", "Derecha"]:
		if not _planta_local.has(lado):
			continue
		var i: int = _huesos["Pantorrilla" + lado]
		var planta := de_esqueleto * (_esqueleto.get_bone_global_pose(i) * (_planta_local[lado] as Vector3))
		var minimo: float = piso + _altura_planta[lado]
		var objetivo := planta
		objetivo.y = maxf(planta.y, minimo)
		if not sentado and not tropezando:
			# Parado, el pie se queda en el piso aunque el cuerpo se ladee; caminando, va libre.
			objetivo.y = lerpf(objetivo.y, minimo, 1.0 - _paso)
		if absf(objetivo.y - planta.y) > 0.002:
			# La rodilla hacia el frente.
			_dos_huesos("Pierna" + lado, "Pantorrilla" + lado, _planta_local[lado], a_esqueleto * objetivo, a_esqueleto.basis * Vector3.FORWARD, 1.0)


## Gira dos huesos encadenados (brazo y antebrazo, o muslo y pantorrilla) para que `punta` (en el
## hueso de abajo) llegue a `objetivo`, con la articulación de en medio hacia `polo` (dirección).
## Todo en coordenadas del esqueleto. `peso` mezcla con la pose que ya tenían.
func _dos_huesos(arriba: String, abajo: String, punta: Vector3, objetivo: Vector3, polo: Vector3, peso: float) -> void:
	if not _huesos.has(arriba) or not _huesos.has(abajo):
		return
	var i1: int = _huesos[arriba]
	var i2: int = _huesos[abajo]
	var g1 := _esqueleto.get_bone_global_pose(i1)
	var g2 := _esqueleto.get_bone_global_pose(i2)
	var s := g1.origin
	var e := g2.origin
	var p := g2 * punta
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(p)
	var hacia := objetivo - s
	if l1 < 0.001 or l2 < 0.001 or hacia.length() < 0.001:
		return
	var direccion := hacia.normalized()
	var d := clampf(hacia.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.001)
	var meta := s + direccion * d
	var coseno := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	# La articulación de en medio se dobla hacia donde ya estaba doblada (la punta no siempre va en
	# línea con los huesos: el pie sale hacia adelante); si iba casi recta, hacia `polo`.
	var lado := (e - s) - direccion * (e - s).dot(direccion)
	if lado.length() < l1 * 0.05:
		lado = polo - direccion * polo.dot(direccion)
		if lado.length_squared() < 0.000001:
			return
	lado = lado.normalized()
	var codo := s + (direccion * coseno + lado * sqrt(1.0 - coseno * coseno)) * l1
	var giro := Quaternion.IDENTITY.slerp(Quaternion((e - s).normalized(), (codo - s).normalized()), peso)
	_esqueleto.set_bone_global_pose(i1, Transform3D(Basis(giro) * g1.basis, s))
	g2 = _esqueleto.get_bone_global_pose(i2)
	e = g2.origin
	p = g2 * punta
	if (p - e).length() < 0.001 or (meta - e).length() < 0.001:
		return
	giro = Quaternion.IDENTITY.slerp(Quaternion((p - e).normalized(), (meta - e).normalized()), peso)
	_esqueleto.set_bone_global_pose(i2, Transform3D(Basis(giro) * g2.basis, e))


## Parpadea cada pocos segundos y mueve la boca: cerrada en reposo, abierta al gritar o del susto,
## y abre y cierra al hablar.
func _animar_cara(delta: float, susto: bool) -> void:
	if _cara.is_empty():
		return
	var parpados: Array = _cara.parpados
	if not parpados.is_empty():
		_para_parpadear -= delta
		if _para_parpadear <= 0.0:
			_parpadeo = 0.0
			_para_parpadear = randf_range(2.0, 5.5)
		var cierre := 0.0
		if _parpadeo >= 0.0:
			_parpadeo += delta / 0.16
			cierre = sin(clampf(_parpadeo, 0.0, 1.0) * PI)
			if _parpadeo >= 1.0:
				_parpadeo = -1.0
		# Del susto, los ojos bien abiertos.
		if susto:
			cierre = 0.0
		for material: ShaderMaterial in parpados:
			material.set_shader_parameter("cierre", cierre)
	if _cara.malla == null:
		return
	_hablando = maxf(0.0, _hablando - delta)
	var objetivo := 0.0
	if _gritando or susto or _clip_nombre == "susto":
		objetivo = 1.0
	elif _hablando > 0.0 or _clip_nombre == "enojo":
		# Abre y cierra como al decir sílabas.
		objetivo = clampf(0.55 + 0.45 * sin(_reloj * 9.0) * sin(_reloj * 3.7 + 1.0), 0.0, 1.0)
	_boca = lerpf(_boca, objetivo, 1.0 - exp(-18.0 * delta))
	# Claves de forma: en reposo "Cerrar" completa; al abrir se pasa a "Abrir".
	var malla: MeshInstance3D = _cara.malla
	malla.set_blend_shape_value(_cara.cerrar, 1.0 - _boca)
	malla.set_blend_shape_value(_cara.abrir, _boca)


## Gira un hueso hacia `objetivo` (euler en los ejes de la figura, alrededor de su articulación):
## la pose local es su reposo por el giro llevado a los ejes del hueso.
func _girar(nombre: String, objetivo: Vector3, t: float) -> void:
	if not _huesos.has(nombre):
		return
	var actual: Vector3 = _giros.get(nombre, Vector3.ZERO)
	actual = actual.lerp(objetivo, t)
	_giros[nombre] = actual
	var i: int = _huesos[nombre]
	var reposo: Basis = (_reposo[i] as Transform3D).basis.orthonormalized()
	var giro := reposo.inverse() * Basis.from_euler(actual) * reposo
	_esqueleto.set_bone_pose_rotation(i, (_esqueleto.get_bone_rest(i).basis.orthonormalized() * giro).get_rotation_quaternion())
