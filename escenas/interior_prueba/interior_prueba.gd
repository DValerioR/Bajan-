extends Node3D
## Escena de prueba del interior (etapas 2 y 3): caminar dentro del camión mientras el piloto
## automático maneja y se detiene en las paradas, donde suben y bajan pasajeros.
## Interior separado (DECISIONES.md, D35). Se puede bajar por la puerta y volver a subir.

const ESCENA_MENU := "res://escenas/principal.tscn"
## Dónde aparece el jugador: junto a la puerta, mirando hacia el fondo (coordenadas del camión).
const PUESTO_JUGADOR := Vector3(0.35, -0.28, -3.0)
const MANIQUI := "chavo_sudadera"

@onready var pista: PistaPrueba = $Pista
@onready var camion: Camion = $Camion
@onready var piloto: PilotoAutomatico = $PilotoAutomatico
@onready var mundo: Node3D = $Mundo
@onready var hud: HudInterior = $Hud

var interior: InteriorCamion
var ragdolls: GestorRagdolls
var pasajeros: GestorPasajeros
var jugador: CuerpoPersonaje
var objetos: Array[ObjetoSuelto] = []
var _arranque: float = 1.5


func _ready() -> void:
	camion.colocar(pista.transform_en_indice(pista.indice_en_distancia(5.0)))
	interior = InteriorCamion.new()
	interior.name = "Interior"
	interior.camion = camion
	interior.mundo = mundo
	add_child(interior)
	ragdolls = GestorRagdolls.new()
	ragdolls.name = "GestorRagdolls"
	ragdolls.interior = interior
	add_child(ragdolls)
	pasajeros = GestorPasajeros.new()
	pasajeros.name = "GestorPasajeros"
	pasajeros.interior = interior
	pasajeros.ragdolls = ragdolls
	pasajeros.pista = pista
	add_child(pasajeros)
	piloto.esperar_mientras = pasajeros.hay_movimiento_en_puerta
	piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	piloto.susto.connect(hud.avisar_susto)

	jugador = _crear_jugador()
	_crear_objetos()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _crear_jugador() -> CuerpoPersonaje:
	var cuerpo := CuerpoPersonaje.new()
	cuerpo.name = "Jugador"
	cuerpo.parametros = ParametrosInterior.cargar()
	var visual := Personaje.new()
	visual.name = "Visual"
	visual.modelo = cuerpo.parametros.modelo
	cuerpo.add_child(visual)
	cuerpo.visual = visual
	var camara := Camera3D.new()
	camara.name = "CamaraJugador"
	camara.fov = 80.0
	camara.near = 0.05
	interior.agregar(cuerpo, camara, Transform3D(Basis(), PUESTO_JUGADOR))
	cuerpo.orientar(PI)
	cuerpo.configurar(visual.altura, visual.altura_ojos)
	visual.ocultar_cabeza(true)
	ragdolls.vigilar(cuerpo)
	var entrada := EntradaJugador.new()
	entrada.name = "EntradaJugador"
	entrada.cuerpo = cuerpo
	add_child(entrada)
	return cuerpo


## Cosas sueltas para probar agarrar, lanzar y empujar (DECISIONES.md, D7).
func _crear_objetos() -> void:
	var maniqui := _objeto("Maniqui", 60.0, _capsula(0.25, 1.5), Vector3(0, 0.75, 0))
	var figura := Personaje.new()
	figura.name = "Figura"
	figura.modelo = MANIQUI
	maniqui.get_node("Visual").add_child(figura)
	_poner(maniqui, Vector3(0.0, -0.28, 0.6))
	var colores := [Color(0.9, 0.25, 0.3), Color(0.25, 0.6, 0.9), Color(0.95, 0.75, 0.2)]
	for k in 3:
		var bolsa := _objeto("Bolsa%d" % k, 3.0, _caja(Vector3(0.4, 0.32, 0.28)), Vector3.ZERO)
		_malla_caja(bolsa, Vector3(0.4, 0.32, 0.28), colores[k])
		_poner(bolsa, Vector3(-0.15 + 0.15 * k, -0.1, 2.0 + 0.5 * k))
	for k in 8:
		var moneda := _objeto("Moneda%d" % k, 0.05, _cilindro(0.06, 0.03), Vector3.ZERO)
		var malla := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.06
		cilindro.bottom_radius = 0.06
		cilindro.height = 0.03
		cilindro.radial_segments = 10
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.78, 0.25)
		cilindro.material = material
		malla.mesh = cilindro
		moneda.get_node("Visual").add_child(malla)
		_poner(moneda, Vector3(-0.3 + 0.08 * k, -0.2, -1.2 + 0.1 * k))
	EstiloToon.aplicar(self)


func _objeto(nombre: String, masa: float, forma: Shape3D, centro: Vector3) -> ObjetoSuelto:
	var objeto := ObjetoSuelto.new()
	objeto.name = nombre
	objeto.mass = masa
	var colision := CollisionShape3D.new()
	colision.shape = forma
	colision.position = centro
	objeto.add_child(colision)
	var visual := Node3D.new()
	visual.name = "Visual"
	objeto.add_child(visual)
	return objeto


func _poner(objeto: ObjetoSuelto, donde: Vector3) -> void:
	objetos.append(objeto)
	interior.agregar(objeto, null, Transform3D(Basis(), donde))


func _malla_caja(objeto: ObjetoSuelto, medidas: Vector3, color: Color) -> void:
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = medidas
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	caja.material = material
	malla.mesh = caja
	objeto.get_node("Visual").add_child(malla)


func _capsula(radio: float, alto: float) -> CapsuleShape3D:
	var forma := CapsuleShape3D.new()
	forma.radius = radio
	forma.height = alto
	return forma


func _caja(medidas: Vector3) -> BoxShape3D:
	var forma := BoxShape3D.new()
	forma.size = medidas
	return forma


func _cilindro(radio: float, alto: float) -> CylinderShape3D:
	var forma := CylinderShape3D.new()
	forma.radius = radio
	forma.height = alto
	return forma


func _physics_process(delta: float) -> void:
	if _arranque > 0.0:
		_arranque -= delta
		if _arranque <= 0.0:
			piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	hud.mostrar_estado(camion.velocidad_adelante * 3.6, PilotoAutomatico.NOMBRES[piloto.modo], interior.esta_dentro(jugador) or jugador.desplomado, jugador.sujetado, jugador.tropezando > 0.0 or jugador.desplomado)
	hud.mostrar_pasajeros(pasajeros.a_bordo())


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("salir_al_menu"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)
	elif evento.is_action_pressed("reiniciar_camion"):
		_reiniciar()
	elif evento.is_action_pressed("piloto_parado"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.PARADO)
	elif evento.is_action_pressed("piloto_tranquilo"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.TRANQUILO)
	elif evento.is_action_pressed("piloto_normal"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.NORMAL)
	elif evento.is_action_pressed("piloto_loco"):
		piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
	elif evento is InputEventMouseButton and evento.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Pone el camión sobre la calle y al jugador de vuelta junto a la puerta.
func _reiniciar() -> void:
	ragdolls.levantar_todos()
	var i := pista.indice_cercano(camion.global_position)
	camion.colocar(pista.transform_en_indice(i))
	interior.inercia.reiniciar()
	piloto.reiniciar()
	interior.recolocar(jugador, Transform3D(Basis(), PUESTO_JUGADOR))
	jugador.orientar(PI)
