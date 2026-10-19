class_name ParametrosRoles
extends RefCounted
## Parámetros del voceador, el vendedor y los bots del interior, leídos de config/roles.cfg.

const RUTA := "res://config/roles.cfg"

var gasto_aliento := 22.0
var recupera_aliento := 14.0
var aliento_minimo := 15.0
var alcance_grito := 40.0
var segundos_por_pasajero := 1.6
var max_atraidos_por_parada := 4
var alcance_ayuda := 2.5

var mercancia := 10
var propina := [3, 6]
var probabilidad_compra := 0.6
var alcance_venta := 1.6
var perdida_tropiezo := 1
var perdida_caida := 3
var puesto_cada := 3
var alcance_puesto := 1.8

var rapidez_bot := 0.75
var reaccion_bot := 0.45
var umbral_sujetarse := 3.5
var probabilidad_fallar := 0.25
var vendedor_sube := 0.5
var vendedor_paradas := [2, 3]

var segundos_extra_rotacion := 6.0
var espera_sin_chofer := 8.0


static func cargar() -> ParametrosRoles:
	var p := ParametrosRoles.new()
	var c := Config.archivo_config(RUTA)
	p.gasto_aliento = c.get_value("voceador", "gasto_aliento", p.gasto_aliento)
	p.recupera_aliento = c.get_value("voceador", "recupera_aliento", p.recupera_aliento)
	p.aliento_minimo = c.get_value("voceador", "aliento_minimo", p.aliento_minimo)
	p.alcance_grito = c.get_value("voceador", "alcance_grito", p.alcance_grito)
	p.segundos_por_pasajero = c.get_value("voceador", "segundos_por_pasajero", p.segundos_por_pasajero)
	p.max_atraidos_por_parada = c.get_value("voceador", "max_atraidos_por_parada", p.max_atraidos_por_parada)
	p.alcance_ayuda = c.get_value("voceador", "alcance_ayuda", p.alcance_ayuda)
	p.mercancia = c.get_value("vendedor", "mercancia", p.mercancia)
	p.propina = c.get_value("vendedor", "propina", p.propina)
	p.probabilidad_compra = c.get_value("vendedor", "probabilidad_compra", p.probabilidad_compra)
	p.alcance_venta = c.get_value("vendedor", "alcance", p.alcance_venta)
	p.perdida_tropiezo = c.get_value("vendedor", "perdida_tropiezo", p.perdida_tropiezo)
	p.perdida_caida = c.get_value("vendedor", "perdida_caida", p.perdida_caida)
	p.puesto_cada = c.get_value("vendedor", "puesto_cada", p.puesto_cada)
	p.alcance_puesto = c.get_value("vendedor", "alcance_puesto", p.alcance_puesto)
	p.rapidez_bot = c.get_value("bots", "rapidez", p.rapidez_bot)
	p.reaccion_bot = c.get_value("bots", "reaccion", p.reaccion_bot)
	p.umbral_sujetarse = c.get_value("bots", "umbral_sujetarse", p.umbral_sujetarse)
	p.probabilidad_fallar = c.get_value("bots", "probabilidad_fallar", p.probabilidad_fallar)
	p.vendedor_sube = c.get_value("bots", "vendedor_sube", p.vendedor_sube)
	p.vendedor_paradas = c.get_value("bots", "vendedor_paradas", p.vendedor_paradas)
	p.segundos_extra_rotacion = c.get_value("paro", "segundos_extra", p.segundos_extra_rotacion)
	p.espera_sin_chofer = c.get_value("paro", "espera_sin_chofer", p.espera_sin_chofer)
	return p


## Si la parada k tiene puesto de dulces (la terminal no cuenta).
func tiene_puesto(k: int, total_paradas: int) -> bool:
	return k > 0 and k < total_paradas - 1 and (k - 2) % maxi(puesto_cada, 1) == 0
