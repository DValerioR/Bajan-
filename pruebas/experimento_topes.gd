extends Node
## Experimento de ajuste (no es prueba automática): pasa el camión sobre un tope a varias
## velocidades y con varios valores de patada_topes, y reporta brinco y tiempo en el aire.

const ESCENA := "res://escenas/calle_prueba/calle_prueba.tscn"

var camion: Camion
var pista: Calle


func _ready() -> void:
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	escena.get_node("EntradaChofer").queue_free()
	camion = escena.camion
	pista = escena.pista
	var centro := (pista.puntos[0] + pista.puntos[pista.puntos.size() / 2]) * 0.5
	var z_tope := centro.z - 20.0
	var tope := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var cilindro := CylinderShape3D.new()
	cilindro.radius = 0.45
	cilindro.height = 8.0
	forma.shape = cilindro
	forma.rotation_degrees = Vector3(0, 0, 90)
	forma.position = Vector3(centro.x, 0.13 - 0.45, z_tope)
	tope.add_child(forma)
	add_child(tope)
	await get_tree().physics_frame

	for patada in [0.0, 0.25, 0.4, 0.6]:
		for velocidad_kmh in [30.0, 50.0, 70.0]:
			camion.parametros.patada_topes = patada
			camion.colocar(Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), Vector3(centro.x, 1.0, centro.z + 70.0)))
			var aire := 0.0
			var subida := 0.0
			var cabeceo := 0.0
			var altura_base := 0.0
			var fase := 0
			for _k in 60 * 12:
				var c := camion.comandos
				c.limpiar()
				var v := camion.velocidad_adelante * 3.6
				c.acelerar = 1.0 if v < velocidad_kmh else 0.0
				await get_tree().physics_frame
				if fase == 0 and camion.global_position.z < z_tope + 12.0:
					fase = 1
					altura_base = camion.global_position.y
				if fase == 1:
					subida = maxf(subida, camion.global_position.y - altura_base)
					cabeceo = maxf(cabeceo, rad_to_deg(absf(camion.global_rotation.x)))
					if camion.ruedas_en_suelo == 0:
						aire += 1.0 / 60.0
					if camion.global_position.z < z_tope - 25.0:
						break
			print("patada %4.1f | %3.0f km/h | brinco %.2f m | cabeceo máx. %4.1f° | en el aire %.2f s" % [patada, velocidad_kmh, subida, cabeceo, aire])
	get_tree().quit()
