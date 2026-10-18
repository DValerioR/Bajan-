# Herramienta (Blender): termina los personajes de muñeco por piezas que corta procesar_personajes.
# Godot los corta en 6 piezas a resolución completa (--sin-reducir) y aquí, por cada pieza:
#   1. Se sueldan los vértices que el .glb separa en las costuras de la textura.
#   2. Se tapan los cortes: caras nuevas pintadas del color de la orilla (la ropa o la piel de
#      junto). Sin esto, al levantar un brazo o doblar una pierna se ve el hueco y el interior negro.
#   3. Se reduce a los triángulos de modelos/personajes.cfg. Blender reduce la malla soldada, así
#      que no abre grietas en las costuras (la reducción de Godot sí las abría).
#   4. Se le copian las normales del modelo completo, para que se vea suave como el original.
#
# Uso (lo llama procesar_personajes.bat si encuentra Blender):
#   blender --background --factory-startup --python scripts/herramientas/tapar_cortes.py -- <carpeta> [nombre ...]
# Sin nombres revisa todos los .glb de la carpeta. Los que ya están terminados no se tocan (para no
# volver a comprimir su textura): cada pieza terminada lleva la marca "cortes_tapados".

import os
import re
import sys

import bmesh
import bpy
from mathutils import Vector

MARCA = "cortes_tapados"
# Distancia (m) para soldar los vértices que el .glb separa en las costuras de la textura.
SOLDAR = 0.0002
CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "modelos", "personajes.cfg")


def triangulos_objetivo(nombre):
	"""Triángulos del personaje según personajes.cfg: los de su hoja o los generales (0 = sin reducir)."""
	general = 6000
	por_hoja = {}
	seccion = ""
	with open(CONFIG, encoding="utf-8") as archivo:
		for linea in archivo:
			linea = linea.strip()
			if linea.startswith("[") and linea.endswith("]"):
				seccion = linea[1:-1]
				por_hoja.setdefault(seccion, {})
			elif "=" in linea and not linea.startswith(";"):
				clave, valor = [t.strip() for t in linea.split("=", 1)]
				por_hoja.setdefault(seccion, {})[clave] = valor
	general = int(por_hoja.get("general", {}).get("triangulos_por_personaje", general))
	for datos in por_hoja.values():
		if nombre in re.findall(r'"([^"]*)"', datos.get("nombres", "")):
			return int(datos.get("triangulos_por_personaje", general))
	return general


def tapar(objeto):
	"""Suelda la pieza y cierra sus huecos. Devuelve cuántas caras nuevas puso."""
	malla = objeto.data
	bm = bmesh.new()
	bm.from_mesh(malla)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=SOLDAR)
	bm.verts.index_update()
	bordes = [arista for arista in bm.edges if arista.is_boundary]
	nuevas = []
	if bordes:
		capa_uv = bm.loops.layers.uv.active
		# UV de cada vértice tomada de una de sus esquinas originales.
		uv_de = {}
		if capa_uv is not None:
			for cara in bm.faces:
				for esquina in cara.loops:
					uv_de.setdefault(esquina.vert.index, esquina[capa_uv].uv.copy())
		nuevas = _abanicos(bm, bordes)
		for cara in nuevas:
			# Toda la cara del color de la orilla de su primer vértice: sin estirar la textura.
			if capa_uv is not None:
				uv = uv_de.get(cara.loops[0].vert.index)
				if uv is not None:
					for esquina in cara.loops:
						esquina[capa_uv].uv = uv
	for cara in bm.faces:
		cara.smooth = True
	abiertos = sum(1 for arista in bm.edges if arista.is_boundary)
	if abiertos:
		print("    %s: %d aristas siguen abiertas" % (objeto.name, abiertos))
	bm.to_mesh(malla)
	bm.free()
	# Quita lo que el relleno haya dejado chueco (caras repetidas o sin área).
	malla.validate(clean_customdata=False)
	return len(nuevas)


def _abanicos(bm, bordes):
	"""Cierra cada hueco con un abanico de triángulos desde su centro: uno por arista de la orilla,
	con la vuelta contraria a la de la cara de junto (así mira hacia afuera igual que ella).
	Funciona aunque la orilla sea enredada o se toque a sí misma."""
	pendientes = set(bordes)
	nuevas = []
	while pendientes:
		# Un hueco: las aristas de orilla conectadas entre sí.
		grupo = []
		pila = [pendientes.pop()]
		while pila:
			arista = pila.pop()
			grupo.append(arista)
			for v in arista.verts:
				for otra in v.link_edges:
					if otra in pendientes:
						pendientes.discard(otra)
						pila.append(otra)
		puntos = {v for arista in grupo for v in arista.verts}
		centro = bm.verts.new(sum((v.co for v in puntos), Vector()) / len(puntos))
		for arista in grupo:
			esquina = arista.link_loops[0]
			a, b = esquina.vert, esquina.link_loop_next.vert
			try:
				nuevas.append(bm.faces.new((b, a, centro)))
			except ValueError:
				pass
	bm.normal_update()
	return nuevas


def aplicar(objeto, modificador):
	with bpy.context.temp_override(object=objeto, active_object=objeto, selected_objects=[objeto]):
		bpy.ops.object.modifier_apply(modifier=modificador.name)


def terminar_pieza(objeto, proporcion):
	# Copia del original completo, con sus normales, para pasárselas a la pieza ya reducida.
	referencia = objeto.copy()
	referencia.data = objeto.data.copy()
	bpy.context.scene.collection.objects.link(referencia)
	nuevas = tapar(objeto)
	if proporcion < 1.0:
		reducir = objeto.modifiers.new("Reducir", "DECIMATE")
		reducir.decimate_type = "COLLAPSE"
		reducir.ratio = proporcion
		reducir.use_collapse_triangulate = True
		aplicar(objeto, reducir)
	if objeto.data.has_custom_normals:
		with bpy.context.temp_override(object=objeto, active_object=objeto, selected_objects=[objeto]):
			bpy.ops.mesh.customdata_custom_splitnormals_clear()
	normales = objeto.modifiers.new("Normales", "DATA_TRANSFER")
	normales.object = referencia
	normales.use_object_transform = True
	normales.use_loop_data = True
	normales.data_types_loops = {"CUSTOM_NORMAL"}
	normales.loop_mapping = "POLYINTERP_NEAREST"
	aplicar(objeto, normales)
	objeto.data.validate(clean_customdata=False)
	bpy.data.objects.remove(referencia, do_unlink=True)
	objeto[MARCA] = 1
	return nuevas


def procesar(ruta):
	nombre = os.path.basename(ruta)[:-4]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=ruta)
	piezas = [o for o in bpy.data.objects if o.type == "MESH"]
	if piezas and all(o.get(MARCA) for o in piezas):
		print("  %s: ya estaba terminado" % nombre)
		return
	antes = sum(len(o.data.polygons) for o in piezas)
	objetivo = triangulos_objetivo(nombre)
	proporcion = 1.0 if objetivo <= 0 else min(1.0, objetivo / max(antes, 1))
	tapas = sum(terminar_pieza(o, proporcion) for o in piezas)
	despues = sum(len(o.data.polygons) for o in piezas)
	bpy.ops.export_scene.gltf(
		filepath=ruta,
		export_format="GLB",
		export_image_format="JPEG",
		export_jpeg_quality=90,
		export_extras=True,
		export_yup=True,
		export_apply=False,
		export_animations=False,
		export_cameras=False,
		export_lights=False,
	)
	print("  %s: %d -> %d triángulos, %d caras de tapa" % (nombre, antes, despues, tapas))


def main():
	argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if not argumentos:
		print("Uso: blender --background --python tapar_cortes.py -- <carpeta> [nombre ...]")
		sys.exit(1)
	carpeta = argumentos[0]
	nombres = argumentos[1:]
	archivos = sorted(f for f in os.listdir(carpeta) if f.endswith(".glb"))
	if nombres:
		archivos = [f for f in archivos if f[:-4] in nombres]
	print("Terminando %d personajes:" % len(archivos))
	for archivo in archivos:
		procesar(os.path.join(carpeta, archivo))


main()
