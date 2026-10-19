class_name Sintetizador
extends RefCounted
## Sonidos de relleno generados en código (DISEÑO.md, sección 10).
## Se sustituirán por archivos de audio/efectos/ cuando existan.

const FRECUENCIA_MUESTREO := 22050


## Rumor de motor diésel en bucle. Dura 1 s con frecuencias enteras para que el bucle no truene.
static func motor() -> AudioStreamWAV:
	var muestras := PackedFloat32Array()
	muestras.resize(FRECUENCIA_MUESTREO)
	for i in FRECUENCIA_MUESTREO:
		var t := float(i) / FRECUENCIA_MUESTREO
		var sierra := 2.0 * fmod(t * 55.0, 1.0) - 1.0
		var cuadrada := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
		var tremolo := 0.75 + 0.25 * sin(TAU * 11.0 * t)
		muestras[i] = (0.55 * sierra + 0.2 * cuadrada) * tremolo * 0.6
	return _crear(muestras, true)


## Claxon de dos tonos desafinados, en bucle mientras se mantiene presionado.
static func claxon() -> AudioStreamWAV:
	var muestras := PackedFloat32Array()
	muestras.resize(FRECUENCIA_MUESTREO)
	for i in FRECUENCIA_MUESTREO:
		var t := float(i) / FRECUENCIA_MUESTREO
		var tono_a := 1.0 if fmod(t * 370.0, 1.0) < 0.5 else -1.0
		var tono_b := 1.0 if fmod(t * 466.0, 1.0) < 0.5 else -1.0
		muestras[i] = (tono_a + tono_b) * 0.3
	return _crear(muestras, true)


## Dos pitidos cortos y agudos para anunciar un evento (no se repite).
static func aviso() -> AudioStreamWAV:
	var duracion := 0.42
	var muestras := PackedFloat32Array()
	muestras.resize(int(FRECUENCIA_MUESTREO * duracion))
	for i in muestras.size():
		var t := float(i) / FRECUENCIA_MUESTREO
		var en_pitido := t < 0.16 or (t > 0.24 and t < 0.4)
		var tono := 880.0 if t < 0.2 else 1175.0
		muestras[i] = (0.35 * sin(TAU * tono * t) + 0.12 * sin(TAU * tono * 2.0 * t)) if en_pitido else 0.0
	return _crear(muestras, false)


## Grito del voceador ("¡aaah!"): voz ronca con vibrato, en bucle mientras grita.
## Frecuencias enteras en 1 s para que el bucle no truene.
static func grito() -> AudioStreamWAV:
	var muestras := PackedFloat32Array()
	muestras.resize(FRECUENCIA_MUESTREO)
	# Armónicos de una "a" abierta: fuertes cerca de 700 y 1200 Hz.
	var pesos := [0.5, 0.6, 0.9, 1.0, 0.7, 0.45, 0.3, 0.2]
	for i in FRECUENCIA_MUESTREO:
		var t := float(i) / FRECUENCIA_MUESTREO
		var fase := TAU * (196.0 * t - 3.0 / (TAU * 6.0) * cos(TAU * 6.0 * t))
		var voz := 0.0
		for h in pesos.size():
			voz += pesos[h] * sin(fase * (h + 1))
		var ronquera := randf_range(-0.15, 0.15)
		muestras[i] = (voz * 0.11 + ronquera * 0.2) * (0.85 + 0.15 * sin(TAU * 3.0 * t))
	return _crear(muestras, true)


static func _crear(muestras: PackedFloat32Array, en_bucle: bool) -> AudioStreamWAV:
	var datos := PackedByteArray()
	datos.resize(muestras.size() * 2)
	for i in muestras.size():
		datos.encode_s16(i * 2, int(clampf(muestras[i], -1.0, 1.0) * 32767.0))
	var sonido := AudioStreamWAV.new()
	sonido.format = AudioStreamWAV.FORMAT_16_BITS
	sonido.mix_rate = FRECUENCIA_MUESTREO
	sonido.stereo = false
	sonido.data = datos
	if en_bucle:
		sonido.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sonido.loop_begin = 0
		sonido.loop_end = muestras.size()
	return sonido
