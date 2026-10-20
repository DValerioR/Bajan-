# Herramienta (Blender): boca animada para los personajes de muñeco por piezas.
# A la pieza Cabeza le agrega dos claves de forma (shape keys) que el juego mezcla:
#   Cerrar: la mandíbula sube `cierre` grados (en reposo: los que tienen la boca abierta de par en
#           par la cierran).
#   Abrir:  la mandíbula baja `apertura` grados (al hablar o gritar).
# La mandíbula no se corta: cada vértice gira sobre la bisagra con un peso que se desvanece hacia
# los cachetes, la nuca y el cuello, así la cara se deforma suave y sin grietas. Para bocas
# cerradas (labios pintados juntos) se puede "rasgar" la línea entre los labios, así al abrirse
# se separan; por la abertura se ve el interior oscuro de la cabeza (el juego lo dibuja así).
#
# Los números salen de modelos/personajes.cfg (en metros, coordenadas de la figura de Godot):
#   boca = [labio_y, bisagra_adelante, bisagra_y, cierre, apertura, centro_x, medio_ancho, rasgar]
#   cara_giro = grados hacia donde ve la cara (0 = al frente; positivo = hacia la izquierda).
#
# Uso (lo llama procesar_personajes.bat después de tapar_cortes.py):
#   blender --background --factory-startup --python scripts/herramientas/caras_blender.py -- <carpeta> [nombre ...]
# Solo toca los que tienen `boca` en el cfg y no tienen ya la marca "cara_hecha" en la cabeza.

import json
import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

MARCA = "cara_hecha"
CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "modelos", "personajes.cfg")


def leer_cfg():
	"""Secciones de personajes.cfg: {seccion: {clave: valor}} (las listas como listas)."""
	datos = {}
	seccion = ""
	with open(CONFIG, encoding="utf-8") as archivo:
		for linea in archivo:
			linea = linea.strip()
			if linea.startswith("[") and linea.endswith("]"):
				seccion = linea[1:-1]
				datos.setdefault(seccion, {})
			elif "=" in linea and not linea.startswith(";"):
				clave, valor = [t.strip() for t in linea.split("=", 1)]
				try:
					datos[seccion][clave] = json.loads(valor)
				except ValueError:
					datos[seccion][clave] = valor.strip('"')
	return datos


# Godot (Y arriba, frente -Z) <-> Blender (Z arriba): el exportador de glTF hace (x, y, z) -> (x, -z, y).
def a_godot(v):
	return Vector((v.x, v.z, -v.y))


def a_blender(v):
	return Vector((v.x, -v.z, v.y))


def suave(a, b, x):
	"""smoothstep de a a b (funciona también con a > b)."""
	if a == b:
		return 1.0 if x >= b else 0.0
	t = max(0.0, min(1.0, (x - a) / (b - a)))
	return t * t * (3.0 - 2.0 * t)


def girar(punto, centro, eje, grados):
	return centro + Matrix.Rotation(math.radians(grados), 3, eje) @ (punto - centro)


def procesar(ruta, cfg):
	nombre = os.path.basename(ruta)[:-4]
	datos = cfg.get(nombre, {})
	if "boca" not in datos:
		return
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=ruta)
	cabeza = next((o for o in bpy.data.objects if o.type == "MESH" and o.name.split(".")[0] == "Cabeza"), None)
	if cabeza is None:
		print("  %s: sin pieza Cabeza" % nombre)
		return
	if cabeza.get(MARCA):
		print("  %s: la boca ya estaba hecha" % nombre)
		return
	boca = datos["boca"]
	labio_y, bisagra_adelante, bisagra_y, cierre, apertura = [float(x) for x in boca[:5]]
	centro_x = float(boca[5]) if len(boca) > 5 else 0.0
	medio_ancho = float(boca[6]) if len(boca) > 6 else 0.14
	rasgar = len(boca) > 7 and bool(boca[7])
	giro = math.radians(float(datos.get("cara_giro", 0.0)))
	# En coordenadas de Godot: hacia dónde ve la cara, el eje de la bisagra (de lado) y la bisagra.
	frente = Vector((-math.sin(giro), 0.0, -math.cos(giro)))
	eje = Vector((math.cos(giro), 0.0, -math.sin(giro)))
	bisagra = Vector((0.0, bisagra_y, 0.0)) + frente * bisagra_adelante
	centro_boca = Vector((centro_x, 0.0, 0.0))
	mundo = cabeza.matrix_world
	al_objeto = mundo.inverted()
	cuello_y = a_godot(mundo.translation).y

	malla = cabeza.data
	bm = bmesh.new()
	bm.from_mesh(malla)
	lado_de_abajo = {}
	if rasgar:
		lado_de_abajo = _rasgar_labios(bm, mundo, al_objeto, labio_y, frente, eje, centro_boca, medio_ancho, bisagra_adelante)
	bm.to_mesh(malla)
	bm.free()

	def peso(i, p):
		adelante = p.x * frente.x + p.z * frente.z
		lateral = abs((p - centro_boca).dot(eje))
		w = suave(bisagra_adelante - 0.04, bisagra_adelante + 0.01, adelante)
		w *= 1.0 - suave(medio_ancho, medio_ancho * 1.8, lateral)
		if i in lado_de_abajo:
			w *= 1.0 if lado_de_abajo[i] else 0.0
		else:
			w *= suave(labio_y, labio_y - 0.012, p.y)
		w *= suave(cuello_y, cuello_y + 0.02, p.y)
		return w

	posiciones = [a_godot(mundo @ v.co) for v in malla.vertices]
	pesos = [peso(i, p) for i, p in enumerate(posiciones)]
	if not cabeza.data.shape_keys:
		cabeza.shape_key_add(name="Base", from_mix=False)
	for clave, grados in (("Cerrar", cierre), ("Abrir", apertura)):
		forma = cabeza.shape_key_add(name=clave, from_mix=False)
		for i, p in enumerate(posiciones):
			if pesos[i] <= 0.0:
				continue
			nueva = girar(p, bisagra, eje, grados * pesos[i])
			forma.data[i].co = al_objeto @ a_blender(nueva)
	movidos = sum(1 for w in pesos if w > 0.0)
	cabeza[MARCA] = 1
	bpy.ops.export_scene.gltf(
		filepath=ruta,
		export_format="GLB",
		export_image_format="AUTO",
		export_extras=True,
		export_yup=True,
		export_apply=False,
		export_morph=True,
		export_morph_normal=True,
		export_animations=False,
		export_cameras=False,
		export_lights=False,
	)
	print("  %s: boca con claves de forma (%d vértices se mueven%s)" % (nombre, movidos, ", labios rasgados" if rasgar else ""))


def _rasgar_labios(bm, mundo, al_objeto, labio_y, frente, eje, centro_boca, medio_ancho, bisagra_adelante):
	"""Corta la cara por la línea de los labios (solo al frente y a lo ancho de la boca) y separa
	el corte, así el labio de abajo puede bajar. Devuelve {índice de vértice: es del lado de abajo}
	para los vértices del corte."""
	en_boca = []
	for cara in bm.faces:
		c = a_godot(mundo @ cara.calc_center_median())
		adelante = c.x * frente.x + c.z * frente.z
		if adelante > bisagra_adelante and abs((c - centro_boca).dot(eje)) < medio_ancho and abs(c.y - labio_y) < 0.03:
			en_boca.append(cara)
	if not en_boca:
		return {}
	# El plano del corte en coordenadas del objeto: horizontal en Godot, a la altura del labio.
	punto = al_objeto @ a_blender(Vector((0.0, labio_y, 0.0)))
	normal = (al_objeto.to_3x3() @ a_blender(Vector((0.0, 1.0, 0.0)))).normalized()
	geom = list({v for f in en_boca for v in f.verts}) + list({e for f in en_boca for e in f.edges}) + en_boca
	resultado = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=punto, plane_no=normal, dist=0.0005)
	cortadas = [e for e in resultado["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
	# Solo las aristas del corte que están dentro de la boca.
	dentro = []
	for e in cortadas:
		m = a_godot(mundo @ ((e.verts[0].co + e.verts[1].co) / 2.0))
		if abs((m - centro_boca).dot(eje)) < medio_ancho * 0.95:
			dentro.append(e)
	if dentro:
		bmesh.ops.split_edges(bm, edges=dentro)
	bm.verts.index_update()
	bm.faces.ensure_lookup_table()
	lado = {}
	for v in bm.verts:
		p = a_godot(mundo @ v.co)
		if abs(p.y - labio_y) > 0.001 or not v.link_faces:
			continue
		promedio = sum((a_godot(mundo @ f.calc_center_median()).y for f in v.link_faces), 0.0) / len(v.link_faces)
		lado[v.index] = promedio < labio_y
	return lado


def main():
	argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if not argumentos:
		print("Uso: blender --background --python caras_blender.py -- <carpeta> [nombre ...]")
		sys.exit(1)
	carpeta = argumentos[0]
	nombres = argumentos[1:]
	cfg = leer_cfg()
	archivos = sorted(f for f in os.listdir(carpeta) if f.endswith(".glb"))
	if nombres:
		archivos = [f for f in archivos if f[:-4] in nombres]
	print("Bocas animadas:")
	for archivo in archivos:
		procesar(os.path.join(carpeta, archivo), cfg)


main()
