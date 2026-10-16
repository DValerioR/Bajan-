class_name PlanEventos
extends RefCounted
## Decide qué eventos de caos pasan en una ruta y dónde (etapa 5). Es puro dato, a partir de la
## descripción de GeneradorRuta y una semilla, para poder probarlo sin abrir la escena:
## - en cada tramo entre dos paradas pasa al menos un evento (criterio de la etapa 5);
## - nada queda pegado a una parada (salvo el inspector, que sube en la parada);
## - cada tipo se puede apagar en config/eventos.cfg (activo=false).
## Cada evento: {tipo, inicio, fin, tramo, parada}. inicio y fin son metros sobre la calle;
## parada solo la usa el inspector (la parada donde sube).
## Los eventos de calle (topes, bache gigante) se agregan a la descripción antes de construirla.

const RUTA := "res://config/eventos.cfg"
const TIPOS := ["topes", "bache_gigante", "animales", "bloqueo", "lluvia", "inspector", "carrerita", "prisa"]


## `activos`: null = lo que diga config/eventos.cfg; o un arreglo con los tipos permitidos
## (para las pruebas).
static func generar(descripcion: Dictionary, semilla: int, activos: Variant = null) -> Array[Dictionary]:
	var cfg := Config.archivo_config(RUTA)
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla * 7919 + 13
	var permitidos: Array = []
	for tipo in TIPOS:
		var encendido: bool = cfg.get_value(tipo, "activo", true) if activos == null else tipo in activos
		if encendido:
			permitidos.append(tipo)
	var eventos: Array[Dictionary] = []
	if permitidos.is_empty():
		return eventos
	var por_tramo: Array = cfg.get_value("general", "por_tramo", [1, 2])
	var lejos: float = cfg.get_value("general", "lejos_de_parada", 22.0)
	var paradas: Array = descripcion.paradas
	var ultima := paradas.size() - 1

	for j in ultima:
		var desde: float = paradas[j]
		var hasta: float = paradas[j + 1]
		var a := desde + lejos
		var b := hasta - lejos
		var largo_tramo := hasta - desde
		# Qué tipos caben en este tramo.
		var validos: Array = permitidos.filter(func(tipo):
			match tipo:
				"inspector":
					return j + 1 < ultima
				"carrerita":
					return largo_tramo >= float(cfg.get_value("carrerita", "tramo_minimo", 110.0))
				"topes":
					return b - a >= float(cfg.get_value("topes", "cantidad", 4)) * float(cfg.get_value("topes", "separacion", 7.0))
				"bache_gigante", "animales", "bloqueo":
					return b - a >= 8.0
			return true)
		if validos.is_empty():
			continue
		var cuantos := mini(azar.randi_range(por_tramo[0], por_tramo[1]), validos.size())
		var elegidos: Array = []
		for _k in cuantos:
			var pesos := validos.map(func(tipo): return float(cfg.get_value(tipo, "peso", 1.0)))
			var tipo: String = validos[_elegir(azar, pesos)]
			elegidos.append(tipo)
			validos.erase(tipo)
			# Prisa con la calle mojada es choque seguro: no van en el mismo tramo.
			if tipo == "lluvia":
				validos.erase("prisa")
			elif tipo == "prisa":
				validos.erase("lluvia")
			if validos.is_empty():
				break
		# Los que ocupan un lugar de la calle van cada uno en su parte del tramo, sin encimarse.
		var con_lugar := elegidos.filter(func(tipo): return tipo in ["topes", "bache_gigante", "animales", "bloqueo", "lluvia", "prisa"])
		var parte := (b - a) / maxf(1.0, con_lugar.size())
		for tipo in elegidos:
			var evento := {"tipo": tipo, "inicio": 0.0, "fin": 0.0, "tramo": j, "parada": -1}
			var k := con_lugar.find(tipo)
			var inicio_parte := a + parte * maxi(k, 0)
			match tipo:
				"topes":
					var largo: float = float(cfg.get_value("topes", "cantidad", 4) - 1) * float(cfg.get_value("topes", "separacion", 7.0))
					evento.inicio = minf(azar.randf_range(inicio_parte, maxf(inicio_parte, inicio_parte + parte - largo)), b - largo)
					evento.fin = evento.inicio + largo
				"bache_gigante":
					var largo: float = cfg.get_value("bache_gigante", "largo", 5.0)
					evento.inicio = minf(azar.randf_range(inicio_parte, maxf(inicio_parte, inicio_parte + parte - largo)), b - largo)
					evento.fin = evento.inicio + largo
				"animales", "bloqueo":
					evento.inicio = azar.randf_range(inicio_parte, inicio_parte + parte)
					evento.fin = evento.inicio
				"lluvia", "prisa":
					evento.inicio = azar.randf_range(inicio_parte, inicio_parte + parte)
					evento.fin = evento.inicio + float(cfg.get_value(tipo, "largo", 120.0))
				"inspector":
					evento.parada = j + 1
					evento.inicio = hasta
					evento.fin = hasta
				"carrerita":
					# Empieza al salir de la parada y termina en la siguiente (la que se disputan).
					evento.parada = j + 1
					evento.inicio = desde + 8.0
					evento.fin = hasta
			eventos.append(evento)
	eventos.sort_custom(func(x, y): return x.inicio < y.inicio)
	return eventos


## Agrega a la descripción de la calle lo que construyen los eventos de calle: topes seguidos y
## el bache gigante (los dos carriles).
static func aplicar_a_descripcion(descripcion: Dictionary, eventos: Array[Dictionary]) -> void:
	var cfg := Config.archivo_config(RUTA)
	for evento in eventos:
		match evento.tipo:
			"topes":
				var separacion: float = cfg.get_value("topes", "separacion", 7.0)
				for k in int(cfg.get_value("topes", "cantidad", 4)):
					descripcion.topes.append(float(evento.inicio) + separacion * k)
			"bache_gigante":
				var largo: float = cfg.get_value("bache_gigante", "largo", 5.0)
				descripcion.baches.append([evento.inicio, 0, largo])
				descripcion.baches.append([evento.inicio, 1, largo])


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
