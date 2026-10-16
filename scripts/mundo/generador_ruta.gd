class_name GeneradorRuta
extends RefCounted
## Arma una ruta distinta cada vez encadenando tramos prediseñados (config/tramos.cfg) de las
## cuatro zonas (DISEÑO.md, sección 4):
## - no repite la misma zona más de dos veces seguidas;
## - la dificultad sube con el avance (dentro de la ruta y de una ruta a la siguiente);
## - entre 6 y 10 paradas, todas sobre la calle (alcanzables);
## - voltea curvas en espejo para que el rumbo no se aleje demasiado del de salida, así la
##   ruta nunca se enrosca sobre sí misma.
## Devuelve la descripción que usa Calle.

const RUTA := "res://config/tramos.cfg"
## Distancia mínima entre una parada y un tope o bache (m).
const DISTANCIA_LIBRE_PARADA := 12.0


static func generar(semilla: int, numero_ruta: int = 1) -> Dictionary:
	var cfg := Config.archivo_config(RUTA)
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var rango: Array = cfg.get_value("generador", "paradas", [6, 10])
	var paradas_meta := azar.randi_range(rango[0], rango[1])
	var rumbo_maximo := deg_to_rad(cfg.get_value("generador", "rumbo_maximo", 70.0))
	var tramos := []
	for seccion in cfg.get_sections():
		if cfg.has_section_key(seccion, "zona"):
			tramos.append(_leer_tramo(cfg, seccion))

	var d := {"segmentos": [], "topes": [], "baches": [], "paradas": [], "zonas": [], "cerrada": false, "semilla": semilla, "tramos": []}
	var distancia := 0.0
	var rumbo := 0.0
	var recta_salida: float = cfg.get_value("generador", "recta_salida", 30.0)
	# Salida: recta con la primera parada.
	d.segmentos.append(["recta", recta_salida])
	d.paradas.append(recta_salida * 0.5)
	d.zonas.append([0.0, "popular"])
	distancia += recta_salida
	var zonas_seguidas: Array[String] = []

	# La terminal se agrega al final: aquí se llena hasta una menos.
	while d.paradas.size() < paradas_meta - 1:
		var avance := float(d.paradas.size()) / paradas_meta
		var dificultad_max := clampi(1 + roundi(avance * 2.0) + (numero_ruta - 1) / 2, 1, 3)
		var candidatos := tramos.filter(func(t):
			var repetida: bool = zonas_seguidas.size() >= 2 and zonas_seguidas[-1] == t.zona and zonas_seguidas[-2] == t.zona
			return not repetida and int(t.dificultad) <= dificultad_max)
		# Prefiere tramos de la dificultad más alta permitida (la ruta se pone más fea al avanzar).
		var pesos := candidatos.map(func(t): return 1.0 + 2.0 * float(int(t.dificultad) == dificultad_max))
		var tramo: Dictionary = candidatos[_elegir(azar, pesos)]
		# Espejo si así el rumbo queda más cerca del de salida.
		var giro := _giro_total(tramo.segmentos)
		var espejo := absf(rumbo - giro) < absf(rumbo + giro)
		if absf(rumbo + (-giro if espejo else giro)) > rumbo_maximo:
			espejo = not espejo
		rumbo += -giro if espejo else giro
		for segmento in tramo.segmentos:
			var s: Array = segmento.duplicate()
			if espejo and s[0] == "curva":
				s[2] = -float(s[2])
			d.segmentos.append(s)
		d.zonas.append([distancia, tramo.zona])
		d.tramos.append(tramo.nombre)
		var parada: float = tramo.parada
		for tope in tramo.topes:
			d.topes.append(distancia + float(tope))
		for bache in tramo.baches:
			d.baches.append([distancia + float(bache[0]), bache[1], bache[2]])
		if parada >= 0.0:
			d.paradas.append(distancia + parada)
		distancia += _largo(tramo.segmentos)
		zonas_seguidas.append(tramo.zona)

	# Llegada: recta con la terminal (última parada).
	var recta_llegada: float = cfg.get_value("generador", "recta_llegada", 35.0)
	d.segmentos.append(["recta", recta_llegada])
	d.paradas.append(distancia + recta_llegada * 0.5)
	d.longitud = distancia + recta_llegada
	# Ningún tope ni bache junto a una parada (de cualquier tramo, también la salida y la terminal).
	d.topes = d.topes.filter(func(tope): return d.paradas.all(func(p): return absf(float(tope) - float(p)) >= DISTANCIA_LIBRE_PARADA))
	d.baches = d.baches.filter(func(bache): return d.paradas.all(func(p): return absf(float(bache[0]) - float(p)) >= DISTANCIA_LIBRE_PARADA))
	return d


static func _leer_tramo(cfg: ConfigFile, seccion: String) -> Dictionary:
	return {
		"nombre": seccion,
		"zona": cfg.get_value(seccion, "zona"),
		"segmentos": cfg.get_value(seccion, "segmentos", []),
		"topes": cfg.get_value(seccion, "topes", []),
		"baches": cfg.get_value(seccion, "baches", []),
		"parada": float(cfg.get_value(seccion, "parada", -1.0)),
		"dificultad": int(cfg.get_value(seccion, "dificultad", 1)),
	}


static func _giro_total(segmentos: Array) -> float:
	var giro := 0.0
	for s in segmentos:
		if s[0] == "curva":
			giro += deg_to_rad(float(s[2]))
	return giro


static func _largo(segmentos: Array) -> float:
	var largo := 0.0
	for s in segmentos:
		largo += float(s[1]) if s[0] == "recta" else absf(deg_to_rad(float(s[2]))) * float(s[1])
	return largo


static func _elegir(azar: RandomNumberGenerator, pesos: Array) -> int:
	var total := 0.0
	for p in pesos:
		total += p
	var tiro := azar.randf() * total
	for i in pesos.size():
		tiro -= pesos[i]
		if tiro <= 0.0:
			return i
	return pesos.size() - 1
