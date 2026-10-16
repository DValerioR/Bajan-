class_name EntradaJugador
extends Node
## Convierte las acciones del jugador local en ComandosPersonaje. Es la única parte que lee
## la entrada; el cuerpo del personaje nunca toca Input.

@export var cuerpo: CuerpoPersonaje

var sensibilidad_raton: float = 0.12
var sensibilidad_mando: float = 140.0


func _ready() -> void:
	process_physics_priority = -10
	var p := ParametrosConduccion.cargar()
	sensibilidad_raton = p.sensibilidad_raton
	sensibilidad_mando = p.sensibilidad_mando


func _unhandled_input(evento: InputEvent) -> void:
	# El ratón para mirar se lee directo (DECISIONES.md, D31).
	if cuerpo != null and evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cuerpo.comandos.mirar -= evento.relative * sensibilidad_raton


func _physics_process(delta: float) -> void:
	if cuerpo == null:
		return
	var c := cuerpo.comandos
	c.mover = Vector2(Input.get_axis("mover_izquierda", "mover_derecha"), Input.get_axis("mover_atras", "mover_adelante"))
	c.mirar -= Vector2(Input.get_axis("mirar_izquierda", "mirar_derecha"), Input.get_axis("mirar_arriba", "mirar_abajo")) * sensibilidad_mando * delta
	c.sujetarse = Input.is_action_pressed("sujetarse")
	if Input.is_action_just_pressed("saltar"):
		c.saltar = true
	if Input.is_action_just_pressed("agarrar"):
		c.agarrar = true
	if Input.is_action_just_pressed("accion_principal"):
		c.accion = true
	if Input.is_action_just_pressed("cobrar"):
		c.cobrar = true
