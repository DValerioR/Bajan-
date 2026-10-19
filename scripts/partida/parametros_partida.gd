class_name ParametrosPartida
extends RefCounted
## Parámetros de dinero, cobro y ventana de parada, leídos de config/partida.cfg.

const RUTA := "res://config/partida.cfg"

var pasaje := 12
var penalizacion_reaparecer := 20
var penalizacion_chofer := 15
var caja_chica := 80
var bonificacion := 0.5
var cuota_inicial := 60
var cuota_por_ruta := 30

var alcance_cobro := 1.6
var derrame_tropiezo := 0.3
var valor_moneda := 2
var max_monedas := 12
var alcance_moneda := 0.7
var vida_moneda_en_calle := 3.0
var velocidad_regado := 1.2

var ventana := 10.0
var desesperacion_por_segundo := 0.08
var probabilidad_bajarse := 0.15


static func cargar() -> ParametrosPartida:
	var p := ParametrosPartida.new()
	var c := Config.archivo_config(RUTA)
	p.pasaje = c.get_value("dinero", "pasaje", p.pasaje)
	p.penalizacion_reaparecer = c.get_value("dinero", "penalizacion_reaparecer", p.penalizacion_reaparecer)
	p.penalizacion_chofer = c.get_value("dinero", "penalizacion_chofer", p.penalizacion_chofer)
	p.caja_chica = c.get_value("dinero", "caja_chica", p.caja_chica)
	p.bonificacion = c.get_value("dinero", "bonificacion", p.bonificacion)
	p.cuota_inicial = c.get_value("dinero", "cuota_inicial", p.cuota_inicial)
	p.cuota_por_ruta = c.get_value("dinero", "cuota_por_ruta", p.cuota_por_ruta)
	p.alcance_cobro = c.get_value("cobro", "alcance", p.alcance_cobro)
	p.derrame_tropiezo = c.get_value("cobro", "derrame_tropiezo", p.derrame_tropiezo)
	p.valor_moneda = c.get_value("cobro", "valor_moneda", p.valor_moneda)
	p.max_monedas = c.get_value("cobro", "max_monedas", p.max_monedas)
	p.alcance_moneda = c.get_value("cobro", "alcance_moneda", p.alcance_moneda)
	p.vida_moneda_en_calle = c.get_value("cobro", "vida_moneda_en_calle", p.vida_moneda_en_calle)
	p.velocidad_regado = c.get_value("cobro", "velocidad_regado", p.velocidad_regado)
	p.ventana = c.get_value("parada", "ventana", p.ventana)
	p.desesperacion_por_segundo = c.get_value("parada", "desesperacion_por_segundo", p.desesperacion_por_segundo)
	p.probabilidad_bajarse = c.get_value("parada", "probabilidad_bajarse", p.probabilidad_bajarse)
	return p


func cuota_de_ruta(numero: int) -> int:
	return cuota_inicial + cuota_por_ruta * (numero - 1)
