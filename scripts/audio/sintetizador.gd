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
