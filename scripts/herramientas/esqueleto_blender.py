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
#   5. Reduce a los triángulos de personajes.cfg y rehace los pesos con los automáticos de Blender
#      (por calor desde los huesos: la mano pegada al muslo es del brazo y los hombros se doblan
#      parejo). Le copia las normales del modelo completo y le hornea su textura desde el completo,
#      con UV nuevas y más espacio para la cara.
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
	esqueleto = crear_esqueleto(cabeza, cola)
	cuerpo.parent = esqueleto
	modificador = cuerpo.modifiers.new("Esqueleto", "ARMATURE")
	modificador.object = esqueleto

	# --- Pose T: bajar los brazos y dejarlo como reposo ---
	if "brazos_caidos" in cfg:
		modificador = bajar_brazos(cuerpo, esqueleto, modificador, float(cfg["brazos_caidos"]), cabeza, cola)

	# --- Reducir, pesos automáticos, normales del completo y textura horneada ---
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
	sin_calor = pesos_automaticos(cuerpo, esqueleto)
	separadas = separar_fundidos(cuerpo)
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
	# Hasta 4 huesos por vértice, normalizados (lo que acepta el juego).
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
	bpy.ops.object.vertex_group_normalize_all(lock_active=False)
	tamano = tapar_cortes.valor_de_hoja(nombre, "tamano_textura", 2048)
	hornear(cuerpo, referencia, nombre, tamano, altura)
	bpy.data.objects.remove(referencia, do_unlink=True)
	cuerpo[MARCA] = 1
	esqueleto[MARCA] = 1
	exportar(ruta)
	print("  %s: %d -> %d triángulos, con esqueleto de %d huesos%s%s%s" % (nombre, antes, len(cuerpo.data.polygons), len(PADRES), ", brazos bajados" if "brazos_caidos" in cfg else "", ", %d vértices sin peso automático" % sin_calor if sin_calor else "", ", %d triángulos de mano fundida quitados" % separadas if separadas else ""))


def crear_esqueleto(cabeza, cola):
	"""El esqueleto de 11 huesos del juego, con las articulaciones dadas (coordenadas del mundo)."""
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
		# La Cadera es la raíz: no mueve vértices (la pelvis va con el torso y las piernas).
		h.use_deform = n != "Cadera"
		huesos[n] = h
	for n, padre in PADRES.items():
		if padre:
			huesos[n].parent = huesos[padre]
	bpy.ops.object.mode_set(mode="OBJECT")
	return esqueleto


def bajar_brazos(cuerpo, esqueleto, modificador, grados, cabeza, cola):
	"""Pose T: baja los brazos hasta quedar abiertos `grados` desde la vertical y deja esa pose
	como la de reposo. Devuelve el modificador del esqueleto nuevo."""
	bpy.context.view_layer.objects.active = esqueleto
	bpy.ops.object.mode_set(mode="POSE")
	for lado in ("Izquierdo", "Derecho"):
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
	return modificador


def exportar(ruta):
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


def pesos_automaticos(cuerpo, esqueleto):
	"""Pesos de Blender por calor desde los huesos: siguen la forma del cuerpo, así la mano pegada
	al muslo es del brazo y los hombros se doblan parejo. Los vértices a los que no les llega
	(islas sueltas, partes cerradas) se quedan con los de las piezas. Devuelve cuántos fueron."""
	de_piezas = []
	nombres = {g.index: g.name for g in cuerpo.vertex_groups}
	for v in cuerpo.data.vertices:
		de_piezas.append([(nombres[g.group], g.weight) for g in v.groups if g.weight > 0.0])
	for m in list(cuerpo.modifiers):
		if m.type == "ARMATURE":
			cuerpo.modifiers.remove(m)
	cuerpo.vertex_groups.clear()
	bpy.ops.object.select_all(action="DESELECT")
	cuerpo.select_set(True)
	esqueleto.select_set(True)
	bpy.context.view_layer.objects.active = esqueleto
	bpy.ops.object.parent_set(type="ARMATURE_AUTO")
	grupos = {g.name: g for g in cuerpo.vertex_groups}
	sin_calor = 0
	for v in cuerpo.data.vertices:
		if sum(g.weight for g in v.groups) > 0.01:
			continue
		sin_calor += 1
		for nombre, peso in de_piezas[v.index]:
			if nombre not in grupos:
				grupos[nombre] = cuerpo.vertex_groups.new(name=nombre)
			grupos[nombre].add([v.index], peso, "REPLACE")
	return sin_calor


# Huesos que nunca se tocan en un cuerpo bien hecho: si un triángulo une a dos de estos, es que el
# modelo original trae la mano fundida con el muslo (o el brazo con la pierna).
NO_SE_TOCAN = [
	({"AntebrazoIzquierdo", "AntebrazoDerecho", "BrazoIzquierdo", "BrazoDerecho"}, {"PiernaIzquierda", "PiernaDerecha", "PantorrillaIzquierda", "PantorrillaDerecha"}),
	({"AntebrazoIzquierdo"}, {"Torso", "Cabeza"}),
	({"AntebrazoDerecho"}, {"Torso", "Cabeza"}),
]


def separar_fundidos(cuerpo):
	"""Quita los triángulos que unen partes que no se tocan (la mano fundida con el muslo en el
	modelo original): al levantar el brazo se estiraban en una tira. Tapa los huecos que quedan.
	Devuelve cuántos triángulos quitó."""
	nombres = {g.index: g.name for g in cuerpo.vertex_groups}
	dueno = []
	for v in cuerpo.data.vertices:
		mayor = max(v.groups, key=lambda g: g.weight) if v.groups else None
		dueno.append(nombres.get(mayor.group, "") if mayor else "")
	bm = bmesh.new()
	bm.from_mesh(cuerpo.data)
	quitar = []
	for cara in bm.faces:
		huesos = {dueno[v.index] for v in cara.verts}
		for a, b in NO_SE_TOCAN:
			if huesos & a and huesos & b:
				quitar.append(cara)
				break
	if quitar:
		bordes_antes = {e for e in bm.edges if e.is_boundary}
		bmesh.ops.delete(bm, geom=quitar, context="FACES_ONLY")
		bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_edges], context="VERTS")
		nuevos = [e for e in bm.edges if e.is_boundary and e not in bordes_antes]
		bmesh.ops.holes_fill(bm, edges=nuevos, sides=0)
		bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
	bm.to_mesh(cuerpo.data)
	bm.free()
	return len(quitar)


def hornear(cuerpo, referencia, nombre, tamano, altura):
	"""Le arma al cuerpo ya reducido su propia textura: UV nuevas (la cabeza con más espacio, que es
	lo que más se ve) y los colores horneados desde el modelo completo. Así la reducción no estira
	la textura (con las UV originales, al juntar triángulos se deformaban ojos y detalles)."""
	original = cuerpo.active_material
	# El completo emite el color de su textura.
	para_referencia = original.copy()
	arbol = para_referencia.node_tree
	textura = next(n for n in arbol.nodes if n.type == "TEX_IMAGE")
	salida = next(n for n in arbol.nodes if n.type == "OUTPUT_MATERIAL")
	emision = arbol.nodes.new("ShaderNodeEmission")
	arbol.links.new(textura.outputs["Color"], emision.inputs["Color"])
	arbol.links.new(emision.outputs["Emission"], salida.inputs["Surface"])
	for k in range(len(referencia.data.materials)):
		referencia.data.materials[k] = para_referencia
	# UV nuevas para el reducido.
	capas = cuerpo.data.uv_layers
	viejas = [c.name for c in capas]
	nueva = capas.new(name="Propia")
	capas.active = nueva
	nueva.active_render = True
	for n in viejas:
		capas.remove(capas[n])
	bpy.ops.object.select_all(action="DESELECT")
	cuerpo.select_set(True)
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
	bpy.ops.object.mode_set(mode="OBJECT")
	_agrandar_cabeza(cuerpo, 1.6)
	bpy.context.scene.tool_settings.use_uv_select_sync = True
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.pack_islands(rotate=True, margin=0.003)
	bpy.ops.object.mode_set(mode="OBJECT")
	# El reducido recibe en una imagen nueva lo que emite el completo.
	propio = original.copy()
	propio.name = nombre
	imagen = bpy.data.images.new(nombre + "_albedo", tamano, tamano)
	destino = next(n for n in propio.node_tree.nodes if n.type == "TEX_IMAGE")
	destino.image = imagen
	propio.node_tree.nodes.active = destino
	for k in range(len(cuerpo.data.materials)):
		cuerpo.data.materials[k] = propio
	escena = bpy.context.scene
	escena.render.engine = "CYCLES"
	escena.cycles.device = "CPU"
	escena.cycles.samples = 1
	escena.render.bake.use_selected_to_active = True
	escena.render.bake.cage_extrusion = altura * 0.004
	escena.render.bake.max_ray_distance = altura * 0.012
	bpy.ops.object.select_all(action="DESELECT")
	referencia.select_set(True)
	cuerpo.select_set(True)
	bpy.context.view_layer.objects.active = cuerpo
	bpy.ops.object.bake(type="EMIT", margin=16, margin_type="EXTEND", use_clear=True, use_selected_to_active=True)
	imagen.pack()


def _agrandar_cabeza(cuerpo, factor):
	"""Agranda en las UV los pedazos que son sobre todo de la cabeza (antes de acomodarlos): la
	cara recibe más pixeles."""
	grupo = cuerpo.vertex_groups.get("Cabeza")
	if grupo is None:
		return
	de_cabeza = [0.0] * len(cuerpo.data.vertices)
	for v in cuerpo.data.vertices:
		for g in v.groups:
			if g.group == grupo.index:
				de_cabeza[v.index] = g.weight
	bm = bmesh.new()
	bm.from_mesh(cuerpo.data)
	uv = bm.loops.layers.uv.active
	bm.faces.ensure_lookup_table()
	# Pedazos: caras unidas por una arista cuyas dos esquinas tienen las mismas UV de los dos lados.
	padre = list(range(len(bm.faces)))

	def raiz(i):
		while padre[i] != i:
			padre[i] = padre[padre[i]]
			i = padre[i]
		return i

	for arista in bm.edges:
		caras = arista.link_faces
		if len(caras) != 2:
			continue
		a, b = caras
		iguales = True
		for v in arista.verts:
			ua = next(l[uv].uv for l in a.loops if l.vert == v)
			ub = next(l[uv].uv for l in b.loops if l.vert == v)
			if (ua - ub).length > 1e-6:
				iguales = False
				break
		if iguales:
			padre[raiz(a.index)] = raiz(b.index)
	pedazos = {}
	for cara in bm.faces:
		pedazos.setdefault(raiz(cara.index), []).append(cara)
	for caras in pedazos.values():
		peso = sum(de_cabeza[v.index] for c in caras for v in c.verts) / max(1, sum(len(c.verts) for c in caras))
		if peso < 0.5:
			continue
		esquinas = [l for c in caras for l in c.loops]
		centro = sum((l[uv].uv for l in esquinas), Vector((0.0, 0.0))) / len(esquinas)
		for l in esquinas:
			l[uv].uv = centro + (l[uv].uv - centro) * factor
	bm.to_mesh(cuerpo.data)
	bm.free()


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
