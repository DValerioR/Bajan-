extends Node
## Prueba automática de la etapa 5: eventos de caos, rivales y el chofer de línea fija.
## - El plan de eventos pone al menos uno en cada tramo entre paradas (criterio de la etapa 5),
##   cada tipo se puede apagar, nada queda pegado a una parada, y lluvia y prisa no van juntas.
## - Robo: el ratero sube, le roba el morral al cobrador; si lo tumban se le cae, si no se baja con él.
## - Dos rutas completas con eventos (cada una con la mitad de los tipos): el chofer automático
##   frena ante los animales y la valla, toma el bache despacio, la lluvia baja el agarre y se
##   quita, la prisa lo pone loco y lo regresa, el inspector multa a los que no pagaron, el
##   rival aparece y la carrerita se resuelve, y el chofer nunca sale volando.
## Uso: Godot --headless --fixed-fps 60 res://pruebas/prueba_etapa5.tscn [-- detalle]

const ESCENA := "res://escenas/ruta/ruta.tscn"
const Ruta := preload("res://escenas/ruta/ruta.gd")
const FPS := 60
const GRUPO_A := ["animales", "bloqueo", "bache_gigante", "inspector"]
const GRUPO_B := ["carrerita", "lluvia", "prisa", "topes"]

## Si se corren menos verificaciones que esto, algo se rompió antes de tiempo (un script que no compila).
const VERIFICACIONES_MINIMAS := 25
var _fallos: int = 0
var _verificaciones: int = 0


func _ready() -> void:
	_probar_plan()
	await _probar_ruta(GRUPO_A)
	await _probar_ruta(GRUPO_B)
	await _probar_robo()
	if _verificaciones < VERIFICACIONES_MINIMAS:
		printerr("  FALLO solo se corrieron %d verificaciones (se esperaban al menos %d)" % [_verificaciones, VERIFICACIONES_MINIMAS])
		_fallos += 1
	if _fallos == 0:
		print("PRUEBAS ETAPA 5: todo pasó.")
	else:
		printerr("PRUEBAS ETAPA 5: %d fallo(s)." % _fallos)
	get_tree().quit(0 if _fallos == 0 else 1)


func _verificar(condicion: bool, descripcion: String) -> void:
	_verificaciones += 1
	if condicion:
		print("  ok    ", descripcion)
	else:
		printerr("  FALLO ", descripcion)
		_fallos += 1


# --- Plan de eventos -----------------------------------------------------------

func _probar_plan() -> void:
	print("Plan de eventos (30 rutas):")
	var cfg := Config.archivo_config(PlanEventos.RUTA)
	var lejos: float = cfg.get_value("general", "lejos_de_parada", 22.0)
	var todos_los_tramos := true
	var lejos_de_paradas := true
	var sin_lluvia_con_prisa := true
	var tipos_vistos := {}
	var respeta_config := true
	for semilla in 30:
		var d := GeneradorRuta.generar(semilla, 1 + semilla % 4)
		var eventos := PlanEventos.generar(d, semilla, PlanEventos.TIPOS)
		for j in d.paradas.size() - 1:
			var del_tramo := eventos.filter(func(e): return e.tramo == j)
			if del_tramo.is_empty():
				todos_los_tramos = false
			var tipos := del_tramo.map(func(e): return e.tipo)
			if "lluvia" in tipos and "prisa" in tipos:
				sin_lluvia_con_prisa = false
		for e in eventos:
			tipos_vistos[e.tipo] = true
			if e.tipo in ["topes", "bache_gigante", "animales", "bloqueo"]:
				for p in d.paradas:
					if absf(float(e.inicio) - float(p)) < lejos - 0.01 or absf(float(e.fin) - float(p)) < lejos - 0.01:
						lejos_de_paradas = false
		# Con la configuración tal cual, solo salen los tipos encendidos.
		for e in PlanEventos.generar(d, semilla):
			if not cfg.get_value(e.tipo, "activo", true):
				respeta_config = false
	_verificar(todos_los_tramos, "en cada tramo entre dos paradas pasa al menos un evento")
	_verificar(tipos_vistos.size() == PlanEventos.TIPOS.size(), "salen los %d tipos de evento (%d)" % [PlanEventos.TIPOS.size(), tipos_vistos.size()])
	_verificar(lejos_de_paradas, "topes, bache, animales y bloqueo quedan lejos de las paradas")
	_verificar(sin_lluvia_con_prisa, "lluvia y prisa nunca van en el mismo tramo")
	_verificar(respeta_config, "solo salen los eventos encendidos en config/eventos.cfg")

	# Apagar cada tipo lo quita por completo; sin ninguno encendido no pasa nada.
	var apagar_funciona := true
	var d := GeneradorRuta.generar(5, 2)
	for tipo in PlanEventos.TIPOS:
		var otros := PlanEventos.TIPOS.filter(func(t): return t != tipo)
		for semilla in 10:
			if PlanEventos.generar(d, semilla, otros).any(func(e): return e.tipo == tipo):
				apagar_funciona = false
	_verificar(apagar_funciona, "cada tipo de evento se puede apagar")
	_verificar(PlanEventos.generar(d, 1, []).is_empty(), "con todos apagados no pasa ningún evento")


# --- Rutas con eventos -----------------------------------------------------------

## Una semilla cuya ruta tenga todos los tipos del grupo (y la más variada).
func _semilla_para(grupo: Array) -> int:
	for semilla in range(1, 300):
		var d := GeneradorRuta.generar(semilla, 1)
		var tipos := PlanEventos.generar(d, semilla, grupo).map(func(e): return e.tipo)
		if grupo.all(func(t): return t in tipos):
			return semilla
	return 1


func _probar_ruta(grupo: Array) -> void:
	var semilla := _semilla_para(grupo)
	print("Ruta con %s (semilla %d):" % [", ".join(grupo), semilla])
	Juego.en_partida = false
	Ruta.semilla_forzada = semilla
	Ruta.eventos_activos = grupo
	# Esta prueba es de los eventos: sin bots del interior.
	Ruta.bots_activos = []
	Juego.rol_jugador = "cobrador"
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	escena.piloto.fijar_semilla(semilla)
	escena.pasajeros.fijar_semilla(semilla)
	var gestor: GestorEventos = escena.eventos
	var camion: Camion = escena.camion
	var calle: Calle = escena.calle
	var chofer: CuerpoPersonaje = escena.pasajeros.al_volante
	var detalle := OS.get_cmdline_user_args().has("detalle")
	if detalle:
		gestor.empezo.connect(func(e): print("        empieza %s en %.0f m" % [e.tipo, e.inicio]))
		gestor.termino.connect(func(e): print("        termina %s" % e.tipo))

	var tiempo := 0.0
	var choco_con_obstaculo := false
	var freno_ante_obstaculo := {}
	var velocidad_en_bache := 0.0
	var agarre_con_lluvia := 1.0
	var modo_con_prisa := ""
	var hubo_rival := false
	var chofer_en_su_lugar := true
	while not escena.terminada and tiempo < 900.0:
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
		# Que nadie cobre: así el inspector tiene a quién multar.
		var i := calle.indice_cercano(camion.global_position)
		for e in gestor.eventos:
			if e.get("estado", "") != "activo":
				continue
			match e.tipo:
				"animales", "bloqueo":
					# Distancia del frente del camión al obstáculo, a lo largo de la calle.
					if is_instance_valid(e.get("nodo")):
						var hasta: float = float(e.inicio) - (i * Calle.PASO + 4.1)
						if hasta < 0.5 and absf(float(e.get("lateral", 0.0))) < calle.ancho_carril:
							choco_con_obstaculo = true
						if absf(camion.velocidad_adelante) < 0.3 and hasta < 15.0 and hasta > 0.0:
							freno_ante_obstaculo[e.tipo] = true
				"bache_gigante":
					if absf(i * Calle.PASO - float(e.inicio)) < 3.0:
						velocidad_en_bache = maxf(velocidad_en_bache, camion.velocidad_adelante * 3.6)
				"lluvia":
					agarre_con_lluvia = minf(agarre_con_lluvia, camion.factor_agarre)
				"prisa":
					modo_con_prisa = PilotoAutomatico.NOMBRES[escena.piloto.modo]
				"carrerita":
					hubo_rival = hubo_rival or is_instance_valid(gestor.rival)
		if chofer == null or not is_instance_valid(chofer) or escena.pasajeros.al_volante != chofer or not chofer.sentado or not escena.interior.esta_dentro(chofer):
			chofer_en_su_lugar = false
		if detalle and Engine.get_physics_frames() % (20 * FPS) == 0:
			print("        [%.0f s] %.0f de %.0f m, %.0f km/h, modo %s, parada %d" % [tiempo, i * Calle.PASO, calle.longitud, camion.velocidad_adelante * 3.6, PilotoAutomatico.NOMBRES[escena.piloto.modo], escena.pasajeros.parada_actual])

	var paradas: int = calle.paradas.size()
	var tramos_con_evento := {}
	for e in gestor.eventos:
		if e.get("estado", "pendiente") != "pendiente":
			tramos_con_evento[e.tramo] = true
	_verificar(escena.terminada, "la ruta con eventos llega a la terminal (%.0f s)" % tiempo)
	_verificar(tramos_con_evento.size() == paradas - 1, "pasó al menos un evento en cada tramo (%d de %d)" % [tramos_con_evento.size(), paradas - 1])
	_verificar(grupo.all(func(t): return t in gestor.historial), "pasaron todos los tipos del grupo: %s" % str(gestor.historial))
	_verificar(gestor.eventos.all(func(e): return e.get("estado", "") == "terminado" or e.tipo in ["lluvia", "prisa"]), "todos los eventos terminan")
	_verificar(chofer_en_su_lugar, "el chofer sigue sentado al volante todo el camino (no sale volando)")
	if "animales" in grupo:
		_verificar(freno_ante_obstaculo.has("animales") and not choco_con_obstaculo, "el chofer frena ante los animales sin atropellarlos")
		_verificar(freno_ante_obstaculo.has("bloqueo"), "el chofer espera frente a la valla hasta que la quitan")
		var tope: float = Config.archivo_config(PlanEventos.RUTA).get_value("bache_gigante", "velocidad_chofer", 25.0)
		_verificar(velocidad_en_bache > 0.0 and velocidad_en_bache < tope + 8.0, "el chofer toma el bache gigante despacio (%.0f km/h)" % velocidad_en_bache)
		_verificar(gestor.multas > 0, "el inspector multa a los que no pagaron ($%d)" % gestor.multas)
	if "lluvia" in grupo:
		_verificar(agarre_con_lluvia < 1.0 and camion.factor_agarre == 1.0, "la lluvia baja el agarre (%.1f) y al escampar regresa" % agarre_con_lluvia)
		_verificar(modo_con_prisa == "loco", "con prisa el chofer maneja en modo loco")
		_verificar(hubo_rival and not is_instance_valid(gestor.rival), "aparece el rival y se va al terminar la carrerita (se llevó a %d)" % gestor.pasajeros_robados)
	escena.queue_free()
	Ruta.eventos_activos = null
	await get_tree().physics_frame
	await get_tree().physics_frame


## Robo: con solo ese evento, sube un ratero en cada parada. Al primero se le deja robar y luego
## se le tumba (se le cae el botín en monedas); al segundo se le deja ir con el dinero.
func _probar_robo() -> void:
	print("Ruta con robos:")
	Juego.en_partida = false
	Ruta.semilla_forzada = 4
	Ruta.eventos_activos = ["robo"]
	Ruta.bots_activos = []
	Juego.rol_jugador = "cobrador"
	var escena: Node = load(ESCENA).instantiate()
	add_child(escena)
	await get_tree().physics_frame
	escena.get_node("EntradaJugador").queue_free()
	escena.piloto.fijar_semilla(4)
	escena.pasajeros.fijar_semilla(4)
	var gestor: GestorEventos = escena.eventos
	var cobrador: Cobrador = escena.cobrador
	var jugador: CuerpoPersonaje = escena.jugador
	var ladrones := 0
	var robos := 0
	var tumbado := false
	# En un diccionario: una función anónima no puede cambiar una variable local de afuera.
	var cuenta := {"cayo": 0}
	var monedas_tras_tumbarlo := 0
	var cayo_al_tumbarlo := 0
	var robado_antes := 0
	var botin_segundo := 0
	var tiempo := 0.0
	var visto: BotLadron = null
	while not escena.terminada and tiempo < 900.0:
		jugador.comandos.sujetarse = true
		var ladron := gestor.ladron
		if ladron != null and is_instance_valid(ladron) and ladron != visto:
			visto = ladron
			ladrones += 1
			ladron.se_le_cayo.connect(func(monto): cuenta.cayo += monto)
			print("        [%.0f s] sube un ratero en la parada %d" % [tiempo, ladron.parada_subida])
		# Ya arriba y buscando: que el cobrador traiga algo en el morral.
		if ladron != null and is_instance_valid(ladron) and ladron.estado == BotLadron.Estado.ACECHANDO and cobrador.morral == 0:
			cobrador.morral = 30
		if ladron != null and is_instance_valid(ladron) and ladron.botin > 0 and ladron.estado == BotLadron.Estado.HUYENDO:
			if robos == 0:
				robos = 1
				# Al primero lo tumban (un empujón fuerte) antes de que se baje.
				tumbado = escena.ragdolls.desplomar(Vector3(3.0, 2.0, 0.0), ladron.cuerpo)
				await get_tree().physics_frame
				monedas_tras_tumbarlo = cobrador.monedas_en_el_piso()
				cayo_al_tumbarlo = cuenta.cayo
			elif robos == 1:
				robos = 2
				robado_antes = gestor.robado
				# Lo que se llevó (el morral pudo traer más o menos de los 30 si alguien pagó).
				botin_segundo = ladron.botin
		if robos == 2 and gestor.robado > robado_antes:
			break
		await get_tree().physics_frame
		tiempo += 1.0 / FPS
	_verificar(ladrones >= 2, "en las paradas sube un ratero (%d)" % ladrones)
	_verificar(robos >= 1, "el ratero alcanza al cobrador y le roba el morral")
	_verificar(tumbado and cayo_al_tumbarlo == 30 and monedas_tras_tumbarlo > 0, "si lo tumban, se le cae el botín en monedas ($%d, %d monedas)" % [cayo_al_tumbarlo, monedas_tras_tumbarlo])
	_verificar(robos == 2 and botin_segundo > 0 and gestor.robado - robado_antes == botin_segundo, "si nadie lo detiene, se baja con el dinero ($%d de $%d)" % [gestor.robado - robado_antes, botin_segundo])
	_verificar(not gestor.historial.is_empty() and gestor.historial.all(func(t): return t == "robo"), "solo pasan robos cuando solo están encendidos los robos")
	escena.queue_free()
	Ruta.eventos_activos = null
	await get_tree().physics_frame
	await get_tree().physics_frame

