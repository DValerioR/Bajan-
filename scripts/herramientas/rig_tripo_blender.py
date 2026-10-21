# Herramienta (Blender): personajes que Tripo ya entrega con esqueleto (rig estilo Mixamo, en FBX).
# Se conservan sus pesos (mejores que los que se calculan aquí) juntándolos en los 11 huesos del
# juego, y se arma el mismo esqueleto que esqueleto_blender.py:
#   Spine, Spine1, Spine2 y Hips -> Torso; Neck mitad Torso, mitad Cabeza; Head -> Cabeza;
#   Shoulder mitad Torso, mitad Brazo; Arm -> Brazo; ForeArm, Hand y dedos -> Antebrazo;
#   UpLeg -> Pierna; Leg, Foot y Toe -> Pantorrilla.
# Lo voltea para que mire al frente del juego, lo escala a su estatura (`altura`) con los pies en
# el piso, baja los brazos de la pose T (`brazos_caidos`) y deja la textura de `tamano_textura`.
# A veces Tripo pone la articulación de la cabeza muy arriba (en la boca, como al cobrador y al
# luchador): `cabeza_en` (fracción de la estatura) la pone bajo la barbilla, y el peso del cuello y
# de la cabeza pasa de Torso a Cabeza a lo largo del cuello, hasta quedar todo en Cabeza ahí.
#
# En modelos/personajes.cfg cada uno es una hoja con `rig` en lugar de `archivo`:
#   [Senor]
#   rig="res://modelos/fuentes/senor/senor.fbx"
#   nombres=["senor"]
#   altura=1.68
#   brazos_caidos=14
#
# Uso: blender --background --factory-startup --python scripts/herramientas/rig_tripo_blender.py -- <carpeta> [--forzar] [nombre ...]
# Sin --forzar, los .glb que ya existen no se tocan.

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import esqueleto_blender  # noqa: E402
import tapar_cortes  # noqa: E402

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
# Hueso de Tripo (sin "mixamorig:", y sin Left/Right) -> {hueso del juego: parte del peso}.
# "Lado" se cambia por Izquierdo/Derecho (o Izquierda/Derecha en las piernas).
DESTINOS = {
	"Hips": {"Torso": 1.0},
	"Spine": {"Torso": 1.0},
	"Spine1": {"Torso": 1.0},
	"Spine2": {"Torso": 1.0},
	"Neck": {"Torso": 0.5, "Cabeza": 0.5},
	"Head": {"Cabeza": 1.0},
	"HeadTop_End": {"Cabeza": 1.0},
	"Shoulder": {"Torso": 0.5, "BrazoLado": 0.5},
	"Arm": {"BrazoLado": 1.0},
	"ForeArm": {"AntebrazoLado": 1.0},
	"Hand": {"AntebrazoLado": 1.0},
	"UpLeg": {"PiernaLada": 1.0},
	"Leg": {"PantorrillaLada": 1.0},
	"Foot": {"PantorrillaLada": 1.0},
	"ToeBase": {"PantorrillaLada": 1.0},
	"Toe_End": {"PantorrillaLada": 1.0},
}


def hojas_con_rig():
	"""Las hojas de personajes.cfg que traen `rig`: [(ruta del fbx, nombre, {clave: valor})]."""
	hojas = {}
	seccion = ""
	with open(tapar_cortes.CONFIG, encoding="utf-8") as archivo:
		for linea in archivo:
			linea = linea.strip()
			if linea.startswith("[") and linea.endswith("]"):
				seccion = linea[1:-1]
			elif "=" in linea and not linea.startswith(";"):
				clave, valor = [t.strip() for t in linea.split("=", 1)]
				hojas.setdefault(seccion, {})[clave] = valor.strip('"')
	lista = []
	for datos in hojas.values():
		if "rig" not in datos:
			continue
		ruta = os.path.join(RAIZ, datos["rig"].replace("res://", ""))
		for nombre in datos["nombres"].strip("[]").replace('"', "").split(","):
			lista.append((ruta, nombre.strip(), datos))
	return lista


def destino_de(hueso):
	"""A qué huesos del juego va el peso de un hueso de Tripo ({} si no se conoce)."""
	nombre = hueso.split(":")[-1]
	lado = ""
	for prefijo in ("Left", "Right"):
		if nombre.startswith(prefijo):
			lado = prefijo
			nombre = nombre[len(prefijo):]
	# Los dedos (HandIndex1, HandThumb2, ...) van con la mano.
	if nombre.startswith("Hand"):
		nombre = "Hand"
	destinos = DESTINOS.get(nombre, {})
	resultado = {}
	for n, parte in destinos.items():
		n = n.replace("Lado", "Izquierdo" if lado == "Left" else "Derecho")
		n = n.replace("Lada", "Izquierda" if lado == "Left" else "Derecha")
		resultado[n] = parte
	return resultado


def convertir(fbx, nombre, datos, salida):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=fbx)
	rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	cuerpo = next(o for o in bpy.data.objects if o.type == "MESH")
	articulacion = {b.name.split(":")[-1]: rig.matrix_world @ b.head_local for b in rig.data.bones}
	puntas = {b.name.split(":")[-1]: rig.matrix_world @ b.tail_local for b in rig.data.bones}

	# La malla sola, en coordenadas del mundo.
	for m in list(cuerpo.modifiers):
		cuerpo.modifiers.remove(m)
	mundo = cuerpo.matrix_world.copy()
	cuerpo.parent = None
	cuerpo.data.transform(mundo)
	cuerpo.matrix_world = Matrix.Identity(4)
	cuerpo.name = "Cuerpo"
	cuerpo.data.name = "Cuerpo"

	# Voltearlo (Tripo lo entrega mirando a -Y; el juego espera +Y), pies en 0, centrado y a su estatura.
	girar = Matrix.Rotation(math.pi, 4, "Z")
	puntos = [girar @ v.co for v in cuerpo.data.vertices]
	piso = min(p.z for p in puntos)
	alto = max(p.z for p in puntos) - piso
	centro = Vector(((min(p.x for p in puntos) + max(p.x for p in puntos)) / 2.0, (min(p.y for p in puntos) + max(p.y for p in puntos)) / 2.0, piso))
	altura = float(datos.get("altura", 1.7))
	ajuste = Matrix.Scale(altura / alto, 4) @ Matrix.Translation(-centro) @ girar
	cuerpo.data.transform(ajuste)
	for tabla in (articulacion, puntas):
		for k in tabla:
			tabla[k] = ajuste @ tabla[k]

	# Pesos: los de Tripo, juntados en los huesos del juego.
	cabeza_en = float(datos["cabeza_en"]) * altura if "cabeza_en" in datos else None
	if cabeza_en is not None:
		articulacion["Head"].z = cabeza_en
	viejos = {g.index: g.name for g in cuerpo.vertex_groups}
	nuevos = {}
	for v in cuerpo.data.vertices:
		suma = {}
		for g in v.groups:
			destinos = destino_de(viejos[g.group])
			if cabeza_en is not None and viejos[g.group].split(":")[-1] in ("Neck", "Head", "HeadTop_End"):
				cuello = articulacion["Neck"].z
				x = min(max((v.co.z - cuello) / max(cabeza_en - cuello, 0.001), 0.0), 1.0)
				destinos = {"Torso": 1.0 - x * x * (3.0 - 2.0 * x), "Cabeza": x * x * (3.0 - 2.0 * x)}
			for destino, parte in destinos.items():
				suma[destino] = suma.get(destino, 0.0) + g.weight * parte
		nuevos[v.index] = suma
	cuerpo.vertex_groups.clear()
	grupos = {n: cuerpo.vertex_groups.new(name=n) for n in esqueleto_blender.PADRES if n != "Cadera"}
	for i, suma in nuevos.items():
		for destino, peso in suma.items():
			if peso > 0.001:
				grupos[destino].add([i], peso, "REPLACE")
	bpy.data.objects.remove(rig, do_unlink=True)

	# Articulaciones del esqueleto del juego.
	cabeza = {}
	cola = {}
	cabeza["Cadera"] = articulacion["Hips"].copy()
	cola["Cadera"] = articulacion["Hips"] + Vector((0.0, 0.0, altura * 0.05))
	cabeza["Torso"] = articulacion["Hips"].copy()
	cola["Torso"] = articulacion["Head"].copy()
	cabeza["Cabeza"] = articulacion["Head"].copy()
	cola["Cabeza"] = Vector((articulacion["Head"].x, articulacion["Head"].y, altura))
	for juego, tripo in (("Izquierdo", "Left"), ("Derecho", "Right")):
		cabeza["Brazo" + juego] = articulacion[tripo + "Arm"].copy()
		cola["Brazo" + juego] = articulacion[tripo + "ForeArm"].copy()
		cabeza["Antebrazo" + juego] = articulacion[tripo + "ForeArm"].copy()
		cola["Antebrazo" + juego] = puntas.get(tripo + "HandMiddle4", puntas[tripo + "Hand"]).copy()
	for juego, tripo in (("Izquierda", "Left"), ("Derecha", "Right")):
		cabeza["Pierna" + juego] = articulacion[tripo + "UpLeg"].copy()
		cola["Pierna" + juego] = articulacion[tripo + "Leg"].copy()
		rodilla = articulacion[tripo + "Leg"]
		cabeza["Pantorrilla" + juego] = rodilla.copy()
		cola["Pantorrilla" + juego] = Vector((rodilla.x, rodilla.y, 0.04 * altura))
	esqueleto = esqueleto_blender.crear_esqueleto(cabeza, cola)
	cuerpo.parent = esqueleto
	modificador = cuerpo.modifiers.new("Esqueleto", "ARMATURE")
	modificador.object = esqueleto
	if "brazos_caidos" in datos:
		esqueleto_blender.bajar_brazos(cuerpo, esqueleto, modificador, float(datos["brazos_caidos"]), cabeza, cola)
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.select_all(action="DESELECT")
	cuerpo.select_set(True)
	bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
	bpy.ops.object.vertex_group_normalize_all(lock_active=False)

	# Textura: la suya, al tamaño de las demás y con el nombre que espera el juego.
	tamano = int(datos.get("tamano_textura", tapar_cortes.valor_de_hoja(nombre, "tamano_textura", 2048)))
	material = cuerpo.active_material
	material.name = nombre
	imagen = next((n.image for n in material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
	if imagen is not None:
		if imagen.size[0] > tamano:
			imagen.scale(tamano, tamano)
		imagen.name = nombre + "_albedo"
		# El exportador nombra la imagen por su archivo: se empaca y se le da el nombre propio.
		imagen.pack()
		imagen.filepath_raw = "//" + nombre + "_albedo.jpg"
	cuerpo[esqueleto_blender.MARCA] = 1
	esqueleto[esqueleto_blender.MARCA] = 1
	esqueleto_blender.exportar(salida)
	print("  %s: %d triángulos, esqueleto de Tripo juntado en %d huesos%s" % (nombre, sum(len(p.vertices) - 2 for p in cuerpo.data.polygons), len(esqueleto_blender.PADRES), ", brazos bajados" if "brazos_caidos" in datos else ""))


def main():
	argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if not argumentos:
		print("Uso: blender --background --python rig_tripo_blender.py -- <carpeta> [--forzar] [nombre ...]")
		sys.exit(1)
	carpeta = argumentos[0]
	forzar = "--forzar" in argumentos
	nombres = [a for a in argumentos[1:] if not a.startswith("--")]
	print("Personajes con rig de Tripo:")
	for fbx, nombre, datos in hojas_con_rig():
		if nombres and nombre not in nombres:
			continue
		salida = os.path.join(carpeta, nombre + ".glb")
		if os.path.exists(salida) and not forzar:
			continue
		if not os.path.exists(fbx):
			print("  %s: no está %s" % (nombre, fbx))
			continue
		convertir(fbx, nombre, datos, salida)


if __name__ == "__main__":
	main()
