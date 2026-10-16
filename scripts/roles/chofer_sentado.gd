class_name ChoferSentado
extends Node3D
## La figura del chofer automático (D23): va sentado al volante, cuelga de la carrocería y no
## tiene cuerpo físico, así que nunca sale volando del camión. Mueve los brazos con el volante.
## Lo que maneja de verdad es el PilotoAutomatico, con los mismos comandos que un jugador.

## Asiento del chofer en coordenadas de la carrocería (encima del cojín).
const ASIENTO := Vector3(-0.6, 0.45, -2.68)

@export var camion: Camion
@export var modelo: String = "chofer"

var figura: Personaje


func _ready() -> void:
	figura = Personaje.new()
	figura.name = "Figura"
	figura.modelo = modelo
	add_child(figura)
	# La cadera queda sobre el cojín y la figura mira al frente del camión.
	position = ASIENTO - Vector3.UP * figura.altura_cadera


func _process(delta: float) -> void:
	if camion == null:
		return
	figura.animar(delta, Vector3.ZERO, Vector3(camion.volante, 0.0, 0.0), false, false, false, false, true, true)


## Crea al chofer y lo sienta en la carrocería del camión.
static func sentar_en(camion_destino: Camion, modelo_chofer: String = "chofer") -> ChoferSentado:
	var chofer := ChoferSentado.new()
	chofer.name = "Chofer"
	chofer.camion = camion_destino
	chofer.modelo = modelo_chofer
	camion_destino.get_node("Carroceria").add_child(chofer)
	return chofer
