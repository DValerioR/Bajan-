class_name PilotoAutomatico
extends Node
## Conductor de línea fija (DISEÑO.md, sección 7.3; etapa 5): sigue la curva de la ruta, baja la
## velocidad antes de las curvas, frena en las paradas y, según el modo, mete "sustos": frenazos,
## acelerones y volantazos de golpe. Maneja mal a propósito: se pasa un poco de las paradas y
## toma las curvas abiertas. No esquiva nada; solo frena ante lo que le marcan con `alto_en`
## (animales, bloqueo, el rival de enfrente). Lo usan el chofer automático y los camiones rivales.
## Solo escribe en camion.comandos, como cualquier chofer.

enum Modo { PARADO, TRANQUILO, NORMAL, LOCO }
## Sin nadie al volante, el camión se va frenando con esto (fracción del freno).
const FRENO_SIN_CHOFER := 0.06
## A menos de esto (m) de la próxima parada no mete sustos.
const DISTANCIA_SIN_SUSTOS := 35.0
const NOMBRES := {Modo.PARADO: "parado", Modo.TRANQUILO: "tranquilo", Modo.NORMAL: "normal", Modo.LOCO: "loco"}

signal susto(tipo: String)
signal llego_a_parada(k: int)
signal salio_de_parada(k: int)
## Se atoró y está intentando salir (0 = lo regresó a su carril).
signal se_atoro(intento: int)

@export var camion: Camion
@export var pista: Calle
@export var modo: Modo = Modo.NORMAL
## Si se detiene en las paradas de la pista (como un chofer de verdad).
@export var detenerse_en_paradas: bool = true
## Apagado no toca el camión (cuando maneja el jugador).
@export var activo: bool = true
## Nadie va al volante (el chofer salió volando): el camión sigue de inercia y se va frenando
## poco a poco, sin detenerse en seco (DISEÑO.md, 5.3). Solo se mantiene en su carril, como si el
## volante se quedara derecho; no acelera, no mete sustos ni se detiene en las paradas.
var sin_chofer: bool = false

## Parada donde está detenido ahora, o -1.
var parada_actual: int = -1
## Mientras esto devuelva true (gente subiendo o bajando), espera un poco más en la parada.
var esperar_mientras: Callable
## Si es mayor que 0, espera exactamente esto en cada parada (la ventana de parada, D20).
var espera_fija: float = -1.0
## En una ruta abierta: ya llegó a la terminal y no se mueve más.
var en_terminal: bool = false
## Carril por el que va: 0 = derecho (el normal), 1 = izquierdo (para rebasar).
var carril: int = 0
## Multiplica la velocidad del modo (los rivales van más rápido).
var factor_velocidad: float = 1.0
## Velocidad máxima temporal (m/s) que le pone un evento, o -1.
var velocidad_tope: float = -1.0
## Índice de la calle antes del cual debe detenerse (un obstáculo), o -1.
var alto_en: int = -1
## Si se pasa de la ruta (después de la terminal) en una ruta abierta, se queda quieto.
var respetar_terminal: bool = true

var parametros: ParametrosInterior
var _indice: int = -1
var _azar := RandomNumberGenerator.new()
var _tiempo_para_susto: float = 5.0
var _susto: String = ""
var _tiempo_susto: float = 0.0
var _volantazo: float = 0.0
var _espera: float = 0.0
## Última parada atendida: no se vuelve a detener ahí hasta alejarse.
var _ultima_parada: int = -1
## Cuánto se va a pasar de la próxima parada (manejo malo), sorteado al salir de la anterior.
var _pasada: float = 0.0
## Atorones: segundos queriendo avanzar sin moverse, reversa en curso e intentos seguidos.
var _atorado: float = 0.0
var _reversa: float = 0.0
var _intentos: int = 0
var _desde_ultimo_atoron: float = 0.0


func _ready() -> void:
	process_physics_priority = -10
	parametros = ParametrosInterior.cargar()
	Config.recargado.connect(func(): parametros = ParametrosInterior.cargar())
	_azar.randomize()


## Sustos repetibles (para las pruebas automáticas).
func fijar_semilla(semilla: int) -> void:
	_azar.seed = semilla


func cambiar_modo(nuevo: Modo) -> void:
	modo = nuevo
	_susto = ""
	_tiempo_para_susto = _intervalo_sustos() * _azar.randf_range(0.5, 1.0)


## Toma el volante a media ruta (lo manejaba otro). `parada`: la parada donde está detenido (o -1),
## donde espera `espera` segundos más; `ultima`: la última parada que ya se atendió.
func tomar_volante(parada: int, ultima: int, espera: float) -> void:
	_indice = -1
	en_terminal = false
	_susto = ""
	parada_actual = parada
	_ultima_parada = ultima if parada < 0 else parada
	_espera = espera


## Después de mover el camión a mano, buscar de nuevo dónde está.
func reiniciar() -> void:
	_indice = -1
	en_terminal = false


func _intervalo_sustos() -> float:
	if modo == Modo.PARADO:
		return 0.0
	return float(parametros.piloto[NOMBRES[modo]][2])


func _physics_process(delta: float) -> void:
	if not activo:
		return
	var c := camion.comandos
	c.limpiar()
	if modo == Modo.PARADO:
		c.frenar = 1.0 if camion.velocidad_adelante > 0.3 else 0.0
		return
	var datos: Array = parametros.piloto[NOMBRES[modo]]
	var velocidad_objetivo: float = datos[0] / 3.6
	var lateral: float = datos[1]

	_indice = pista.indice_cercano(camion.global_position, _indice)
	var n := pista.puntos.size()
	# Ruta abierta: después de la última parada, se queda en la terminal.
	if respetar_terminal and not pista.cerrada and not pista.paradas.is_empty() and _indice >= pista.paradas[pista.paradas.size() - 1].indice_camion - 1 and parada_actual < 0 and _ultima_parada == pista.paradas.size() - 1:
		en_terminal = true
	if en_terminal:
		c.frenar = 1.0 if camion.velocidad_adelante > 0.3 else 0.0
		return
	if not sin_chofer and _atender_paradas(delta, c):
		return
	velocidad_objetivo *= factor_velocidad
	if velocidad_tope > 0.0:
		velocidad_objetivo = minf(velocidad_objetivo, velocidad_tope)
	var velocidad := camion.velocidad_adelante
	var adelante := roundi(7.0 + maxf(velocidad, 0.0) * 0.6)
	var i_objetivo := mini(_indice + adelante, n - 1) if not pista.cerrada else (_indice + adelante) % n
	# Curvas abiertas: en las cerradas se carga hacia afuera (manejo malo, D3).
	var giro_firmado := pista.direcciones[_ciclo(_indice + 5)].signed_angle_to(pista.direcciones[_ciclo(_indice + 25)], Vector3.UP)
	var abrir := signf(giro_firmado) * parametros.curvas_abiertas * clampf(absf(giro_firmado) / 0.5, 0.0, 1.0)
	var lado := (0.5 if carril == 0 else -0.5) * pista.ancho_carril + abrir
	var objetivo := pista.puntos[i_objetivo] + pista.derecha(i_objetivo) * lado
	var local := camion.global_transform.affine_inverse() * objetivo
	c.girar = clampf(atan2(local.x, -local.z) * 2.2, -1.0, 1.0)

	var giro_adelante := 0.0
	for k in range(5, 35, 5):
		giro_adelante = maxf(giro_adelante, pista.direcciones[_ciclo(_indice + k)].angle_to(pista.direcciones[_ciclo(_indice + k + 5)]))
	velocidad_objetivo = minf(velocidad_objetivo, sqrt(lateral * 5.0 / maxf(giro_adelante, 0.001)))
	# Frena suave para quedar en la siguiente parada (o ante un obstáculo).
	var hasta_parada := _distancia_a_proxima_parada()
	var frenado := parametros.frenado_parada
	var hasta_obstaculo := _distancia_a_obstaculo()
	if hasta_obstaculo >= 0.0 and (hasta_parada < 0.0 or hasta_obstaculo < hasta_parada):
		hasta_parada = hasta_obstaculo
		frenado = parametros.frenado_obstaculo
	if hasta_parada >= 0.0:
		velocidad_objetivo = minf(velocidad_objetivo, sqrt(2.0 * frenado * maxf(hasta_parada - 0.3, 0.0)))
	if hasta_parada >= 0.0 and hasta_parada < 12.0:
		# Llegando a la parada: control fino de la velocidad para quedar en su lugar.
		if hasta_parada < 1.5:
			c.frenar = 1.0 if velocidad > 0.3 else 0.0
		elif velocidad > velocidad_objetivo + 0.3:
			c.frenar = clampf((velocidad - velocidad_objetivo) / 2.0, 0.3, 1.0)
		elif velocidad < velocidad_objetivo - 0.5:
			c.acelerar = 0.5
	elif velocidad < velocidad_objetivo - 0.5:
		c.acelerar = 1.0
	elif velocidad > velocidad_objetivo + 1.5:
		c.frenar = clampf((velocidad - velocidad_objetivo) / 5.0, 0.2, 1.0)
	else:
		c.acelerar = 0.35

	if sin_chofer:
		c.acelerar = 0.0
		c.frenar = FRENO_SIN_CHOFER if camion.velocidad_adelante > 0.5 else 0.0
		return
	_sustos(delta, c)
	_salir_de_atoron(delta, c, hasta_parada)


## Si se estrelló o se subió a la banqueta y no avanza (pasa con la calle mojada o en un
## choque con el rival), se echa en reversa un momento con el volante al revés. Si después de
## tres intentos sigue atorado, vuelve a su carril: un chofer de verdad se bajaría a empujar.
func _salir_de_atoron(delta: float, c: ComandosConduccion, hasta_parada: float) -> void:
	_desde_ultimo_atoron += delta
	if _reversa > 0.0:
		_reversa -= delta
		c.acelerar = 0.0
		c.frenar = 1.0
		c.girar = -c.girar
		return
	var queriendo := c.acelerar > 0.3 and (hasta_parada < 0.0 or hasta_parada > 6.0)
	_atorado = _atorado + delta if queriendo and absf(camion.velocidad_adelante) < 0.8 else 0.0
	if _atorado < 3.0:
		return
	_atorado = 0.0
	if _desde_ultimo_atoron > 25.0:
		_intentos = 0
	_desde_ultimo_atoron = 0.0
	_intentos += 1
	if _intentos <= 3:
		_reversa = 1.8
	else:
		_intentos = 0
		camion.colocar(pista.transform_en_indice(_indice, carril))
	se_atoro.emit(_intentos)


## Índice de la siguiente parada a la que va (o -1).
func siguiente_parada() -> int:
	return _proxima_parada() if _indice >= 0 else 0


## Detenido en una parada: frena, espera y avisa. Devuelve true mientras está ahí.
func _atender_paradas(delta: float, c: ComandosConduccion) -> bool:
	if not detenerse_en_paradas or pista.paradas.is_empty():
		return false
	if parada_actual >= 0:
		# Parado: suelta los pedales y deja trabajar al freno de estacionamiento
		# (con el camión quieto, el pedal del freno mete reversa).
		c.frenar = 1.0 if camion.velocidad_adelante > 0.3 else 0.0
		_espera -= delta
		var ocupados: bool = esperar_mientras.is_valid() and esperar_mientras.call() and _espera > -parametros.espera_extra_parada
		if _espera <= 0.0 and not ocupados:
			salio_de_parada.emit(parada_actual)
			_ultima_parada = parada_actual
			parada_actual = -1
			_pasada = _azar.randf_range(0.0, parametros.sobrepaso_parada)
		return parada_actual >= 0
	var k := _proxima_parada()
	if k >= 0 and _pasos_hasta(pista.paradas[k].indice_camion) <= 2.5 and absf(camion.velocidad_adelante) < 0.8:
		parada_actual = k
		_espera = espera_fija if espera_fija > 0.0 else parametros.espera_parada
		_susto = ""
		llego_a_parada.emit(k)
		c.frenar = 1.0 if camion.velocidad_adelante > 0.3 else 0.0
		return true
	return false


func _proxima_parada() -> int:
	var mejor := -1
	var mejor_pasos := INF
	var n := pista.puntos.size()
	for k in pista.paradas.size():
		# La parada que acaba de atender no cuenta hasta que el camión se aleje de ella.
		var crudo := posmod(pista.paradas[k].indice_camion - _indice, n)
		if k == _ultima_parada and (crudo > n - 15 or crudo <= 2):
			continue
		var pasos := _pasos_hasta(pista.paradas[k].indice_camion)
		if pasos < mejor_pasos:
			mejor_pasos = pasos
			mejor = k
	return mejor


## Metros por la calle hasta la próxima parada, o -1 si no hay o está lejos.
func _distancia_a_proxima_parada() -> float:
	if not detenerse_en_paradas or pista.paradas.is_empty():
		return -1.0
	var k := _proxima_parada()
	if k < 0:
		return -1.0
	var pasos := _pasos_hasta(pista.paradas[k].indice_camion)
	if pasos >= 80:
		return -1.0
	# Se pasa un poco (manejo malo): el lugar donde para queda `_pasada` metros adelante.
	var firmada := float(posmod(pista.paradas[k].indice_camion - _indice + pista.puntos.size() / 2, pista.puntos.size()) - pista.puntos.size() / 2)
	return maxf(firmada + _pasada, 0.0) * Calle.PASO


## Metros hasta el obstáculo marcado en `alto_en` (con un margen para no tocarlo), o -1.
func _distancia_a_obstaculo() -> float:
	if alto_en < 0:
		return -1.0
	var pasos := alto_en - _indice if not pista.cerrada else posmod(alto_en - _indice, pista.puntos.size())
	if pasos < -2 or pasos > 80:
		return -1.0
	return maxf(float(pasos), 0.0) * Calle.PASO


func _ciclo(i: int) -> int:
	return posmod(i, pista.puntos.size()) if pista.cerrada else clampi(i, 0, pista.puntos.size() - 1)


## Muestras por recorrer (hacia adelante) hasta el índice dado; si ya se pasó un poco, cuenta 0.
func _pasos_hasta(indice: int) -> float:
	var n := pista.puntos.size()
	var pasos := posmod(indice - _indice, n)
	return 0.0 if pasos > n - 4 else float(pasos)


## De vez en cuando, algo de golpe: frenazo, acelerón o volantazo. Cada uno dura un momento.
func _sustos(delta: float, c: ComandosConduccion) -> void:
	var intervalo := _intervalo_sustos()
	if intervalo <= 0.0:
		return
	# Cerca de una parada no mete sustos (y suelta el acelerón): con uno ahí se pasaba de largo.
	var hasta_parada := _distancia_a_proxima_parada()
	var cerca_de_parada := hasta_parada >= 0.0 and hasta_parada < DISTANCIA_SIN_SUSTOS
	if _susto == "aceleron" and cerca_de_parada:
		_susto = ""
		_tiempo_para_susto = intervalo * _azar.randf_range(0.6, 1.4)
	if _susto == "":
		_tiempo_para_susto -= delta
		if _tiempo_para_susto <= 0.0 and camion.velocidad_adelante > 5.0 and not cerca_de_parada:
			_susto = ["frenazo", "frenazo", "aceleron", "volantazo"][_azar.randi() % 4]
			_tiempo_susto = {"frenazo": _azar.randf_range(0.6, 1.3), "aceleron": 1.5, "volantazo": 0.35}[_susto]
			_volantazo = [-1.0, 1.0][_azar.randi() % 2] * 0.6
			susto.emit(_susto)
		return
	_tiempo_susto -= delta
	match _susto:
		"frenazo":
			c.acelerar = 0.0
			c.frenar = 1.0
		"aceleron":
			c.acelerar = 1.0
			c.frenar = 0.0
		"volantazo":
			c.girar = clampf(c.girar + _volantazo, -1.0, 1.0)
	if _tiempo_susto <= 0.0:
		_susto = ""
		_tiempo_para_susto = intervalo * _azar.randf_range(0.6, 1.4)
