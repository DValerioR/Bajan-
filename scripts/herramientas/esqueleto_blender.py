# Herramienta (Blender): convierte un personaje cortado en piezas (procesar_personajes con
# --para-esqueleto) en una sola malla con esqueleto, lista para el juego.
#
#   1. Une las 10 piezas en una malla y suelda los cortes (las piezas comparten los vértices del
#      corte): la piel queda continua.
#   2. Arma el esqueleto con las articulaciones de las piezas (su origen es la articulación):
#      Cadera (raíz) > Torso > Cabeza, Brazo > Antebrazo; Cadera > Pierna > Pantorrilla.
#   3. Pesos: cada vértice es de la pieza de la que venía (así la mano pegada al muslo no se va con la
#      pierna) y, cerca de cada articulación, se reparte entre la pieza y la de arriba con una rampa
#      suave: la piel se dobla en lugar de partirse.
#   4. Si el modelo viene en pose T (brazos_caidos en personajes.cfg), baja los brazos girando los
#      huesos y deja esa pose como la de reposo.
#   5. Reduce a los triángulos de personajes.cfg, le copia las normales del modelo completo y le arma
#      su propia textura (las mismas funciones de tapar_cortes.py).
#
# Uso: blender --background --factory-startup --python scripts/herramientas/esqueleto_blender.py -- <carpeta> [nombre ...]
# Los que ya tienen esqueleto (marca "con_esqueleto") no se tocan.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tapar_cortes  # noqa: E402

MARCA = "con_esqueleto"
SOLDAR = 0.0002
# Jerarquía: hueso -> padre ("" = raíz).
PADRES = {
	"Cadera": "",
	"Torso": "Cadera",
	"Cabeza": "Torso",
	"BrazoIzquierdo": "Torso",
	"BrazoDerecho": "Torso",
	"AntebrazoIzquierdo": "BrazoIzquierdo",
	"AntebrazoDerecho": "BrazoDerecho",
	"PiernaIzquierda": "Cadera",
	"PiernaDerecha": "Cadera",
	"PantorrillaIzquierda": "PiernaIzquierda",
	"PantorrillaDerecha": "PiernaDerecha",
}
# De quién toma peso cada pieza cerca de su articulación (la pieza de arriba), y el ancho de la
# rampa como fracción de la estatura.
RAMPAS = {
	"Cabeza": ("Torso", 0.025),
	"BrazoIzquierdo": ("Torso", 0.04),
	"BrazoDerecho": ("Torso", 0.04),
	"AntebrazoIzquierdo": ("BrazoIzquierdo", 0.03),
	"AntebrazoDerecho": ("BrazoDerecho", 0.03),
	"PiernaIzquierda": ("Torso", 0.045),
	"PiernaDerecha": ("Torso", 0.045),
	"PantorrillaIzquierda": ("PiernaIzquierda", 0.035),
	"PantorrillaDerecha": ("PiernaDerecha", 0.035),
}


def leer_cfg_personaje(nombre):
	"""La sección del personaje en personajes.cfg (solo lo que se necesita aquí)."""
	datos = {}
	seccion = ""
	with open(tapar_cortes.CONFIG, encoding="utf-8") as archivo:
		for linea in archivo:
			linea = linea.strip()
			if linea.startswith("[") and linea.endswith("]"):
				seccion = linea[1:-1]
			elif seccion == nombre and "=" in linea and not linea.startswith(";"):
				clave, valor = [t.strip() for t in linea.split("=", 1)]
				datos[clave] = valor
	return datos


def suave(t):
	t = max(0.0, min(1.0, t))
	return t * t * (3.0 - 2.0 * t)


def armar(ruta):
	nombre = os.path.basename(ruta)[:-4]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=ruta)
	piezas = {}
	for o in bpy.data.objects:
		if o.type == "MESH":
			piezas[o.name.split(".")[0]] = o
	if any(o.get(MARCA) for o in piezas.values()) or any(o.type == "ARMATURE" for o in bpy.data.objects):
		print("  %s: ya tenía esqueleto" % nombre)
		return
	if "Torso" not in piezas or "AntebrazoDerecho" not in piezas:
		print("  %s: no viene en las 10 piezas (falta --para-esqueleto)" % nombre)
		return
	cfg = leer_cfg_personaje(nombre)
	altura = max((o.matrix_world @ v.co).z for o in piezas.values() for v in o.data.vertices)

	# --- Articulaciones y puntas de los huesos (coordenadas del mundo de Blender, Z arriba) ---
	origen = {n: o.matrix_world.translation.copy() for n, o in piezas.items()}

	def punta_mas_lejana(n):
		o = piezas[n]
		return max((o.matrix_world @ v.co for v in o.data.vertices), key=lambda p: (p - origen[n]).length)

	cabeza = {}
	cola = {}
	cabeza["Cadera"] = origen["Torso"].copy()
	cola["Cadera"] = origen["Torso"] + Vector((0.0, 0.0, altura * 0.05))
	cabeza["Torso"] = origen["Torso"].copy()
	cola["Torso"] = origen["Cabeza"].copy()
	cabeza["Cabeza"] = origen["Cabeza"].copy()
	cola["Cabeza"] = Vector((origen["Cabeza"].x, origen["Cabeza"].y, altura))
	for lado in ("Izquierdo", "Derecho"):
		cabeza["Brazo" + lado] = origen["Brazo" + lado].copy()
		cola["Brazo" + lado] = origen["Antebrazo" + lado].copy()
		cabeza["Antebrazo" + lado] = origen["Antebrazo" + lado].copy()
		cola["Antebrazo" + lado] = punta_mas_lejana("Antebrazo" + lado)
	for lado in ("Izquierda", "Derecha"):
		cabeza["Pierna" + lado] = origen["Pierna" + lado].copy()
		cola["Pierna" + lado] = origen["Pantorrilla" + lado].copy()
		rodilla = origen["Pantorrilla" + lado]
		cabeza["Pantorrilla" + lado] = rodilla.copy()
		cola["Pantorrilla" + lado] = Vector((rodilla.x, rodilla.y, 0.04 * altura))

	# --- Una sola malla, con un grupo por pieza ---
	for n, o in piezas.items():
		grupo = o.vertex_groups.new(name=n)
		grupo.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
	bpy.ops.object.select_all(action="DESELECT")
	for o in piezas.values():
		o.select_set(True)
	cuerpo = piezas["Torso"]
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.join()
	cuerpo.name = "Cuerpo"
	cuerpo.data.name = "Cuerpo"
	# Quitar el padre (el nodo raíz del .glb) y dejar la malla en el origen, sin girar.
	mundo = cuerpo.matrix_world.copy()
	cuerpo.parent = None
	cuerpo.data.transform(mundo)
	cuerpo.matrix_world = Matrix.Identity(4)
	for o in list(bpy.data.objects):
		if o.type == "EMPTY":
			bpy.data.objects.remove(o, do_unlink=True)
	bm = bmesh.new()
	bm.from_mesh(cuerpo.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=SOLDAR)
	bm.to_mesh(cuerpo.data)
	bm.free()

	# --- Pesos con rampas en las articulaciones ---
	grupos = {g.name: g for g in cuerpo.vertex_groups}
	indice_de = {g.index: g.name for g in cuerpo.vertex_groups}
	for v in cuerpo.data.vertices:
		propio = max(v.groups, key=lambda e: e.weight) if v.groups else None
		if propio is None:
			continue
		pieza = indice_de[propio.group]
		# Del lado de abajo de la articulación de su pieza: parte del peso es de la pieza de arriba.
		repartos = {pieza: 1.0}
		if pieza in RAMPAS:
			arriba, ancho = RAMPAS[pieza]
			direccion = (cola[pieza] - cabeza[pieza]).normalized()
			d = (v.co - cabeza[pieza]).dot(direccion)
			t = suave((d + ancho * altura) / (2.0 * ancho * altura))
			if t < 1.0:
				repartos = {pieza: t, arriba: 1.0 - t}
		# Del lado de arriba: si la vértice es de la pieza de arriba pero queda cerca de una
		# articulación de abajo, le pasa algo de peso a esa pieza.
		for hija, (arriba, ancho) in RAMPAS.items():
			if arriba != pieza:
				continue
			direccion = (cola[hija] - cabeza[hija]).normalized()
			d = (v.co - cabeza[hija]).dot(direccion)
			if d < -ancho * altura or (v.co - cabeza[hija]).length > ancho * altura * 3.0:
				continue
			t = suave((d + ancho * altura) / (2.0 * ancho * altura))
			if t > 0.0:
				repartos[pieza] = repartos.get(pieza, 1.0) * (1.0 - t)
				repartos[hija] = repartos.get(hija, 0.0) + t
		total = sum(repartos.values())
		for g in list(v.groups):
			grupos[indice_de[g.group]].remove([v.index])
		for n, w in repartos.items():
			if w > 0.001:
				grupos[n].add([v.index], w / total, "REPLACE")

	# --- Esqueleto ---
	datos = bpy.data.armatures.new("Esqueleto")
	esqueleto = bpy.data.objects.new("Esqueleto", datos)
	bpy.context.scene.collection.objects.link(esqueleto)
	bpy.context.view_layer.objects.active = esqueleto
	bpy.ops.object.mode_set(mode="EDIT")
	huesos = {}
	for n in PADRES:
		h = datos.edit_bones.new(n)
		h.head = cabeza[n]
		h.tail = cola[n]
		# Que el eje X del hueso apunte hacia la derecha del personaje (el giro de doblar).
		h.align_roll(Vector((0.0, -1.0, 0.0)))
		huesos[n] = h
	for n, padre in PADRES.items():
		if padre:
			huesos[n].parent = huesos[padre]
	bpy.ops.object.mode_set(mode="OBJECT")
	if "Cadera" not in grupos:
		cuerpo.vertex_groups.new(name="Cadera")
	cuerpo.parent = esqueleto
	modificador = cuerpo.modifiers.new("Esqueleto", "ARMATURE")
	modificador.object = esqueleto

	# --- Pose T: bajar los brazos y dejarlo como reposo ---
	if "brazos_caidos" in cfg:
		grados = float(cfg["brazos_caidos"])
		bpy.context.view_layer.objects.active = esqueleto
		bpy.ops.object.mode_set(mode="POSE")
		for lado, signo in (("Izquierdo", -1.0), ("Derecho", 1.0)):
			hueso = esqueleto.pose.bones["Brazo" + lado]
			actual = (cola["Antebrazo" + lado] - cabeza["Brazo" + lado])
			actual = Vector((actual.x, 0.0, actual.z)).normalized()
			lado_x = 1.0 if actual.x > 0 else -1.0
			objetivo = Vector((lado_x * math.sin(math.radians(grados)), 0.0, -math.cos(math.radians(grados))))
			giro = actual.rotation_difference(objetivo)
			# La rotación del hueso de pose va en su espacio: se convierte desde el del mundo.
			reposo = hueso.bone.matrix_local.to_3x3()
			hueso.rotation_mode = "QUATERNION"
			hueso.rotation_quaternion = (reposo.inverted() @ giro.to_matrix() @ reposo).to_quaternion()
		bpy.context.view_layer.update()
		bpy.ops.object.mode_set(mode="OBJECT")
		bpy.context.view_layer.objects.active = cuerpo
		bpy.ops.object.modifier_apply(modifier=modificador.name)
		bpy.context.view_layer.objects.active = esqueleto
		bpy.ops.object.mode_set(mode="POSE")
		bpy.ops.pose.select_all(action="SELECT")
		bpy.ops.pose.armature_apply()
		bpy.ops.object.mode_set(mode="OBJECT")
		modificador = cuerpo.modifiers.new("Esqueleto", "ARMATURE")
		modificador.object = esqueleto

	# --- Reducir, normales del completo y textura propia ---
	antes = len(cuerpo.data.polygons)
	objetivo = tapar_cortes.valor_de_hoja(nombre, "triangulos_por_personaje", 6000)
	proporcion = 1.0 if objetivo <= 0 else min(1.0, objetivo / max(antes, 1))
	referencia = cuerpo.copy()
	referencia.data = cuerpo.data.copy()
	referencia.modifiers.clear()
	referencia.parent = None
	bpy.context.scene.collection.objects.link(referencia)
	if proporcion < 1.0:
		reducir = cuerpo.modifiers.new("Reducir", "DECIMATE")
		reducir.decimate_type = "COLLAPSE"
		reducir.ratio = proporcion
		reducir.use_collapse_triangulate = True
		# El esqueleto va al final de la pila: primero se reduce.
		bpy.context.view_layer.objects.active = cuerpo
		bpy.ops.object.modifier_move_to_index(modifier=reducir.name, index=0)
		tapar_cortes.aplicar(cuerpo, reducir)
	for cara in cuerpo.data.polygons:
		cara.use_smooth = True
	normales = cuerpo.modifiers.new("Normales", "DATA_TRANSFER")
	normales.object = referencia
	normales.use_object_transform = True
	normales.use_loop_data = True
	normales.data_types_loops = {"CUSTOM_NORMAL"}
	normales.loop_mapping = "POLYINTERP_NEAREST"
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.modifier_move_to_index(modifier=normales.name, index=0)
	tapar_cortes.aplicar(cuerpo, normales)
	bpy.data.objects.remove(referencia, do_unlink=True)
	# Hasta 4 huesos por vértice, normalizados (lo que acepta el juego).
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
	bpy.ops.object.vertex_group_normalize_all(lock_active=False)
	tamano = tapar_cortes.valor_de_hoja(nombre, "tamano_textura", 2048)
	# reempacar trabaja sobre la capa de UV activa de cada pieza.
	tapar_cortes.reempacar([cuerpo], nombre, tamano)
	cuerpo[MARCA] = 1
	esqueleto[MARCA] = 1
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(
		filepath=ruta,
		export_format="GLB",
		export_image_format="JPEG",
		export_jpeg_quality=90,
		export_extras=True,
		export_yup=True,
		export_apply=False,
		export_skins=True,
		export_morph=True,
		export_morph_normal=True,
		export_animations=False,
		export_cameras=False,
		export_lights=False,
	)
	print("  %s: %d -> %d triángulos, con esqueleto de %d huesos%s" % (nombre, antes, len(cuerpo.data.polygons), len(PADRES), ", brazos bajados" if "brazos_caidos" in cfg else ""))


def main():
	argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if not argumentos:
		print("Uso: blender --background --python esqueleto_blender.py -- <carpeta> [nombre ...]")
		sys.exit(1)
	carpeta = argumentos[0]
	nombres = argumentos[1:]
	archivos = sorted(f for f in os.listdir(carpeta) if f.endswith(".glb"))
	if nombres:
		archivos = [f for f in archivos if f[:-4] in nombres]
	print("Esqueletos:")
	for archivo in archivos:
		armar(os.path.join(carpeta, archivo))


if __name__ == "__main__":
	main()
