class_name BotChofer
extends BotInterior
## Bot chofer (DISEÑO.md, sección 7.3): camina al volante y se sienta. Ya sentado, quien maneja de
## verdad es el PilotoAutomatico (D42), que la escena prende mientras haya un bot al volante. Va
## sujeto al asiento: sentado no lo mueve nada y no puede salir volando (D23).


func pensar(_delta: float) -> void:
	if pasajeros.al_volante == cuerpo:
		return
	# Si alguien más va al volante, espera junto a él.
	if caminar_hacia(GestorPasajeros.JUNTO_AL_VOLANTE, 1.0, 0.45) and pasajeros.al_volante == null:
		pasajeros.sentar_al_volante(cuerpo)


func maneja() -> bool:
	return true
