extends Node
## Experimento de rendimiento (no es prueba automática): mide el tiempo por cuadro con 0, 5 y 15
## pasajeros a bordo, con el chofer en modo loco. Sin --headless (y sin --fixed-fps) mide también
## los cuadros por segundo reales con gráficos, desde la cámara del jugador y sin sincronía vertical.

const ESCENA := "res://escenas/interior_prueba/interior_prueba.tscn"


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for cuantos in [0, 5, 15]:
		var escena: Node = load(ESCENA).instantiate()
		add_child(escena)
		await get_tree().physics_frame
		escena.get_node("EntradaJugador").queue_free()
		escena.set_physics_process(false)
		# Sin los que esperan en las paradas: solo los de adentro.
		escena.pasajeros.vaciar()
		escena.pasajeros.llegadas_activas = false
		escena.pasajeros.llenar(cuantos)
		escena.piloto.detenerse_en_paradas = false
		escena.piloto.cambiar_modo(PilotoAutomatico.Modo.LOCO)
		for _k in 120:
			await get_tree().physics_frame
		var n := 600
		var antes := Time.get_ticks_usec()
		var cuadros_dibujados := Engine.get_frames_drawn()
		for _k in n:
			await get_tree().physics_frame
		var total := (Time.get_ticks_usec() - antes) / 1000.0
		if DisplayServer.get_name() == "headless":
			print("%2d pasajeros: %.2f ms por cuadro (todo: física, scripts y lógica, sin dibujar)" % [cuantos, total / n])
		else:
			var dibujados := Engine.get_frames_drawn() - cuadros_dibujados
			print("%2d pasajeros: %.0f cuadros por segundo con gráficos (%.2f ms por cuadro)" % [cuantos, dibujados / (total / 1000.0), total / dibujados])
		escena.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	get_tree().quit()
