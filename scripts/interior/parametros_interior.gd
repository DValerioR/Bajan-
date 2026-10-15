class_name ParametrosInterior
extends RefCounted
## Parámetros de caminar dentro del camión, leídos de config/interior.cfg.

const RUTA := "res://config/interior.cfg"

var velocidad := 3.0
var firmeza := 4.0
var control_aire := 0.15
var salto := 3.6
var velocidad_maxima := 7.0
var radio := 0.27
var modelo := "cobrador"

var exageracion := 1.3
var empujon_maximo := 9.0
var vertical_maximo := 8.0
var suavizado := 0.06
var umbral_tropiezo := 8.0
var duracion_tropiezo := 1.1
var factor_sujetado := 0.15
var alcance_pasamanos := 1.0

var alcance := 2.2
var velocidad_lanzamiento := 9.0
var empujon := 5.0
var exageracion_objetos := 1.3

var piloto := {
	"tranquilo": [30.0, 3.0, 0.0],
	"normal": [45.0, 4.5, 9.0],
	"loco": [65.0, 6.5, 4.0],
}


static func cargar() -> ParametrosInterior:
	var p := ParametrosInterior.new()
	var c := Config.archivo_config(RUTA)
	p.velocidad = c.get_value("jugador", "velocidad", p.velocidad)
	p.firmeza = c.get_value("jugador", "firmeza", p.firmeza)
	p.control_aire = c.get_value("jugador", "control_aire", p.control_aire)
	p.salto = c.get_value("jugador", "salto", p.salto)
	p.velocidad_maxima = c.get_value("jugador", "velocidad_maxima", p.velocidad_maxima)
	p.radio = c.get_value("jugador", "radio", p.radio)
	p.modelo = c.get_value("jugador", "modelo", p.modelo)

	p.exageracion = c.get_value("inercia", "exageracion", p.exageracion)
	p.empujon_maximo = c.get_value("inercia", "empujon_maximo", p.empujon_maximo)
	p.vertical_maximo = c.get_value("inercia", "vertical_maximo", p.vertical_maximo)
	p.suavizado = c.get_value("inercia", "suavizado", p.suavizado)
	p.umbral_tropiezo = c.get_value("inercia", "umbral_tropiezo", p.umbral_tropiezo)
	p.duracion_tropiezo = c.get_value("inercia", "duracion_tropiezo", p.duracion_tropiezo)
	p.factor_sujetado = c.get_value("inercia", "factor_sujetado", p.factor_sujetado)
	p.alcance_pasamanos = c.get_value("inercia", "alcance_pasamanos", p.alcance_pasamanos)

	p.alcance = c.get_value("objetos", "alcance", p.alcance)
	p.velocidad_lanzamiento = c.get_value("objetos", "velocidad_lanzamiento", p.velocidad_lanzamiento)
	p.empujon = c.get_value("objetos", "empujon", p.empujon)
	p.exageracion_objetos = c.get_value("objetos", "exageracion", p.exageracion_objetos)

	for modo in p.piloto:
		p.piloto[modo] = c.get_value("piloto", modo, p.piloto[modo])
	return p
