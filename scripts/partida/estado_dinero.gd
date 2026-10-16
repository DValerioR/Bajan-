class_name EstadoDinero
extends RefCounted
## El dinero de la partida (DISEÑO.md, 6.1 y 6.2; D11, D15, D19). Es lógica pura, sin nodos,
## para poder probarla sola (pruebas/prueba_etapa4.gd).
##
## - Fondo común del equipo. La primera ruta empieza con la caja chica; las siguientes, con lo
##   que quedó de la anterior más una bonificación (fracción de la caja chica).
## - Ganancia de la ruta = lo que entra en ella menos las penalizaciones pagadas en ella.
## - La ruta se cumple si la ganancia alcanza la cuota; entonces la cuota se paga del fondo.
## - Ninguna penalización deja el fondo en negativo, salvo la de reaparecer, que si no alcanza
##   ni se cobra (el jugador queda de espectador; en la etapa 4 todavía reaparece gratis).
## Garantía: el fondo nunca es negativo, y después de pagar la cuota no es menor que al empezar.

var caja_chica: int = 80
var bonificacion: float = 0.5
var fondo: int = 0
var fondo_al_empezar_ruta: int = 0
var ganancia_ruta: int = 0
var cuota: int = 0
var numero_ruta: int = 0
var rutas_cumplidas: int = 0
## Todo lo que ha entrado en la partida (para el récord final).
var total_ganado: int = 0


func empezar_partida(nueva_caja_chica: int, nueva_bonificacion: float) -> void:
	caja_chica = nueva_caja_chica
	bonificacion = nueva_bonificacion
	fondo = 0
	numero_ruta = 0
	rutas_cumplidas = 0
	total_ganado = 0


## Arranca la siguiente ruta con su cuota.
func empezar_ruta(nueva_cuota: int) -> void:
	numero_ruta += 1
	if numero_ruta == 1:
		fondo = caja_chica
	else:
		fondo += roundi(caja_chica * bonificacion)
	fondo_al_empezar_ruta = fondo
	ganancia_ruta = 0
	cuota = nueva_cuota


## Dinero que entra (pasajes, propinas, monedas recogidas).
func ingresar(monto: int) -> void:
	if monto <= 0:
		return
	fondo += monto
	ganancia_ruta += monto
	total_ganado += monto


## Penalización normal: se cobra lo que alcance, el fondo nunca queda en negativo.
## Devuelve lo que sí se cobró.
func penalizar(monto: int) -> int:
	var cobrado := clampi(monto, 0, fondo)
	fondo -= cobrado
	ganancia_ruta -= cobrado
	return cobrado


## Penalización de reaparecer: solo se cobra si alcanza completa. Devuelve si se pudo pagar.
func pagar_reaparicion(monto: int) -> bool:
	if monto > fondo:
		return false
	fondo -= monto
	ganancia_ruta -= monto
	return true


## Gasto en la tiendita (etapa 6). Devuelve si alcanzó.
func gastar(monto: int) -> bool:
	if monto > fondo or monto < 0:
		return false
	fondo -= monto
	return true


func cuota_alcanzada() -> bool:
	return ganancia_ruta >= cuota


## Cierra la ruta: si se cumplió, paga la cuota del fondo. Devuelve si se cumplió.
func cerrar_ruta() -> bool:
	if not cuota_alcanzada():
		return false
	fondo -= cuota
	rutas_cumplidas += 1
	return true
