class_name ParametrosConduccion
extends RefCounted
## Parámetros de conducción leídos de config/conduccion.cfg.
## Los valores por defecto de aquí solo se usan si falta algo en el archivo.

const RUTA := "res://config/conduccion.cfg"

var masa := 3500.0
var centro_masa_y := -0.45
var amortiguacion_angular := 0.6

var largo_reposo := 0.55
var radio_rueda := 0.45
var rigidez := 34.0
var amortiguacion := 4.0
var patada_topes := 0.45
var umbral_patada := 1.0
var patada_maxima := 2.5

var aceleracion := 6.0
var velocidad_maxima := 80.0 / 3.6
var aceleracion_reversa := 3.5
var velocidad_maxima_reversa := 18.0 / 3.6

var frenado := 12.0
var resistencia_rodado := 0.04
var resistencia_aire := 0.0009

var angulo_maximo := deg_to_rad(41.5)
var angulo_a_velocidad_maxima := deg_to_rad(8.0)
var rapidez_volante := 2.4
var retorno_volante := 3.5

var lateral_delantero := 7.0
var lateral_trasero := 5.5
var coeficiente_maximo := 0.95
var altura_fuerzas := 0.6

var enderezar_fuerza := 5.0
var inclinacion_limite := deg_to_rad(25.0)

var inclinacion_lateral_factor := 1.1
var inclinacion_lateral_max := 8.0
var cabeceo_factor := 0.8
var cabeceo_max := 6.0
var balanceo_desde := 50.0 / 3.6
var balanceo_pleno := 70.0 / 3.6
var suavizado_visual := 5.0

var sensibilidad_raton := 0.12
var sensibilidad_mando := 140.0
var limite_horizontal := 110.0
var limite_vertical := 60.0

var volumen_motor := -14.0
var volumen_claxon := -6.0


static func cargar() -> ParametrosConduccion:
	var p := ParametrosConduccion.new()
	var c := Config.archivo_config(RUTA)
	p.masa = c.get_value("camion", "masa", p.masa)
	p.centro_masa_y = c.get_value("camion", "centro_masa_y", p.centro_masa_y)
	p.amortiguacion_angular = c.get_value("camion", "amortiguacion_angular", p.amortiguacion_angular)

	p.largo_reposo = c.get_value("suspension", "largo_reposo", p.largo_reposo)
	p.radio_rueda = c.get_value("suspension", "radio_rueda", p.radio_rueda)
	p.rigidez = c.get_value("suspension", "rigidez", p.rigidez)
	p.amortiguacion = c.get_value("suspension", "amortiguacion", p.amortiguacion)
	p.patada_topes = c.get_value("suspension", "patada_topes", p.patada_topes)
	p.umbral_patada = c.get_value("suspension", "umbral_patada", p.umbral_patada)
	p.patada_maxima = c.get_value("suspension", "patada_maxima", p.patada_maxima)

	p.aceleracion = c.get_value("motor", "aceleracion", p.aceleracion)
	p.velocidad_maxima = c.get_value("motor", "velocidad_maxima_kmh", p.velocidad_maxima * 3.6) / 3.6
	p.aceleracion_reversa = c.get_value("motor", "aceleracion_reversa", p.aceleracion_reversa)
	p.velocidad_maxima_reversa = c.get_value("motor", "velocidad_maxima_reversa_kmh", p.velocidad_maxima_reversa * 3.6) / 3.6

	p.frenado = c.get_value("frenos", "frenado", p.frenado)
	p.resistencia_rodado = c.get_value("frenos", "resistencia_rodado", p.resistencia_rodado)
	p.resistencia_aire = c.get_value("frenos", "resistencia_aire", p.resistencia_aire)

	p.angulo_maximo = deg_to_rad(c.get_value("direccion", "angulo_maximo", rad_to_deg(p.angulo_maximo)))
	p.angulo_a_velocidad_maxima = deg_to_rad(c.get_value("direccion", "angulo_a_velocidad_maxima", rad_to_deg(p.angulo_a_velocidad_maxima)))
	p.rapidez_volante = c.get_value("direccion", "rapidez_volante", p.rapidez_volante)
	p.retorno_volante = c.get_value("direccion", "retorno_volante", p.retorno_volante)

	p.lateral_delantero = c.get_value("agarre", "lateral_delantero", p.lateral_delantero)
	p.lateral_trasero = c.get_value("agarre", "lateral_trasero", p.lateral_trasero)
	p.coeficiente_maximo = c.get_value("agarre", "coeficiente_maximo", p.coeficiente_maximo)
	p.altura_fuerzas = c.get_value("agarre", "altura_fuerzas", p.altura_fuerzas)

	p.enderezar_fuerza = c.get_value("estabilidad", "enderezar_fuerza", p.enderezar_fuerza)
	p.inclinacion_limite = deg_to_rad(c.get_value("estabilidad", "inclinacion_limite", rad_to_deg(p.inclinacion_limite)))

	p.inclinacion_lateral_factor = c.get_value("visual", "inclinacion_lateral_factor", p.inclinacion_lateral_factor)
	p.inclinacion_lateral_max = c.get_value("visual", "inclinacion_lateral_max", p.inclinacion_lateral_max)
	p.cabeceo_factor = c.get_value("visual", "cabeceo_factor", p.cabeceo_factor)
	p.cabeceo_max = c.get_value("visual", "cabeceo_max", p.cabeceo_max)
	p.balanceo_desde = c.get_value("visual", "balanceo_desde_kmh", p.balanceo_desde * 3.6) / 3.6
	p.balanceo_pleno = c.get_value("visual", "balanceo_pleno_kmh", p.balanceo_pleno * 3.6) / 3.6
	p.suavizado_visual = c.get_value("visual", "suavizado", p.suavizado_visual)

	p.sensibilidad_raton = c.get_value("camara", "sensibilidad_raton", p.sensibilidad_raton)
	p.sensibilidad_mando = c.get_value("camara", "sensibilidad_mando", p.sensibilidad_mando)
	p.limite_horizontal = c.get_value("camara", "limite_horizontal", p.limite_horizontal)
	p.limite_vertical = c.get_value("camara", "limite_vertical", p.limite_vertical)

	p.volumen_motor = c.get_value("sonido", "volumen_motor", p.volumen_motor)
	p.volumen_claxon = c.get_value("sonido", "volumen_claxon", p.volumen_claxon)
	return p
