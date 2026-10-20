# Herramienta (Blender): termina los personajes de muñeco por piezas que corta procesar_personajes.
# Godot los corta en 6 piezas a resolución completa (--sin-reducir) y aquí, por cada pieza:
#   1. Se sueldan los vértices que el .glb separa en las costuras de la textura.
#   2. Se tapan los cortes: caras nuevas pintadas del color de la orilla (la ropa o la piel de
#      junto). Sin esto, al levantar un brazo o doblar una pierna se ve el hueco y el interior negro.
#   3. Se reduce a los triángulos de modelos/personajes.cfg. Blender reduce la malla soldada, así
#      que no abre grietas en las costuras (la reducción de Godot sí las abría).
#   4. Se le copian las normales del modelo completo, para que se vea suave como el original.
#   5. Se le arma su propia textura: Tripo pinta a varios personajes en una sola hoja de 4096 px,
#      con sus pedazos revueltos. Aquí se acomodan solo los pedazos de este personaje en una
#      imagen nueva (tamano_textura de personajes.cfg) y se copian ahí los colores de la hoja a
#      resolución completa. Así la cara no se ve borrosa ni con rayas de los pedazos vecinos.
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


def valor_de_hoja(nombre, clave, general):
	"""Un valor de personajes.cfg para este personaje: el de su hoja o, si no lo trae, el general."""
	por_hoja = {}
	seccion = ""
	with open(CONFIG, encoding="utf-8") as archivo:
		for linea in archivo:
			linea = linea.strip()
			if linea.startswith("[") and linea.endswith("]"):
				seccion = linea[1:-1]
				por_hoja.setdefault(seccion, {})
			elif "=" in linea and not linea.startswith(";"):
				llave, valor = [t.strip() for t in linea.split("=", 1)]
				por_hoja.setdefault(seccion, {})[llave] = valor
	general = int(por_hoja.get("general", {}).get(clave, general))
	for datos in por_hoja.values():
		if nombre in re.findall(r'"([^"]*)"', datos.get("nombres", "")):
			return int(datos.get(clave, general))
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


def reempacar(piezas, nombre, tamano):
	"""Le arma al personaje su propia textura de `tamano` px con solo sus pedazos de UV."""
	material = piezas[0].active_material
	arbol = material.node_tree
	textura = next(n for n in arbol.nodes if n.type == "TEX_IMAGE")
	salida = next(n for n in arbol.nodes if n.type == "OUTPUT_MATERIAL")
	superficie = salida.inputs["Surface"].links[0].from_socket
	for objeto in piezas:
		capas = objeto.data.uv_layers
		capas[0].name = "Hoja"
		capas.active = capas.new(name="Propia")

	# Acomodar los pedazos de las 6 piezas juntos en la imagen nueva.
	bpy.ops.object.select_all(action="DESELECT")
	for objeto in piezas:
		objeto.select_set(True)
	bpy.context.view_layer.objects.active = piezas[0]
	bpy.context.scene.tool_settings.use_uv_select_sync = True
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
	bpy.ops.object.mode_set(mode="OBJECT")
	for objeto in piezas:
		_colorear_tapas(objeto)

	# Copiar los colores de la hoja (con las UV viejas) a la imagen nueva (con las nuevas).
	escena = bpy.context.scene
	escena.render.engine = "CYCLES"
	escena.cycles.device = "CPU"
	escena.cycles.samples = 1
	imagen = bpy.data.images.new(nombre + "_albedo", tamano, tamano)
	mapa = arbol.nodes.new("ShaderNodeUVMap")
	mapa.uv_map = "Hoja"
	emision = arbol.nodes.new("ShaderNodeEmission")
	destino = arbol.nodes.new("ShaderNodeTexImage")
	destino.image = imagen
	arbol.links.new(mapa.outputs["UV"], textura.inputs["Vector"])
	arbol.links.new(textura.outputs["Color"], emision.inputs["Color"])
	arbol.links.new(emision.outputs["Emission"], salida.inputs["Surface"])
	arbol.nodes.active = destino
	bpy.ops.object.bake(type="EMIT", margin=16, margin_type="EXTEND", use_clear=True)

	# El material vuelve a ser el de siempre, ahora con la imagen nueva y una sola capa de UV.
	arbol.links.new(superficie, salida.inputs["Surface"])
	textura.image = imagen
	for nodo in (mapa, emision, destino):
		arbol.nodes.remove(nodo)
	for objeto in piezas:
		capas = objeto.data.uv_layers
		capas.remove(capas["Hoja"])
		capas["Propia"].active_render = True


def _colorear_tapas(objeto):
	"""Las tapas tienen todas sus esquinas en el mismo punto de la hoja (el color de la orilla),
	así que al acomodar no ocupan lugar. Se les da a todas sus esquinas un mismo punto: el que ya
	tiene uno de sus vértices en una cara normal, que sí recibe color. (Si cada esquina tomara el
	de su vértice, la tapa se estiraría entre pedazos lejanos y pintaría encima de ellos.)"""
	bm = bmesh.new()
	bm.from_mesh(objeto.data)
	hoja = bm.loops.layers.uv["Hoja"]
	propia = bm.loops.layers.uv["Propia"]

	def es_tapa(cara):
		a, b, c = (esquina[hoja].uv for esquina in cara.loops[:3])
		return abs((b - a).cross(c - a)) < 1e-10

	tapas = {cara for cara in bm.faces if es_tapa(cara)}
	for cara in tapas:
		punto = None
		for esquina in cara.loops:
			for otra in esquina.vert.link_loops:
				if otra.face not in tapas:
					punto = otra[propia].uv.copy()
					break
			if punto is not None:
				break
		if punto is None:
			continue
		for esquina in cara.loops:
			esquina[propia].uv = punto
	bm.to_mesh(objeto.data)
	bm.free()


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
	objetivo = valor_de_hoja(nombre, "triangulos_por_personaje", 6000)
	proporcion = 1.0 if objetivo <= 0 else min(1.0, objetivo / max(antes, 1))
	tapas = sum(terminar_pieza(o, proporcion) for o in piezas)
	despues = sum(len(o.data.polygons) for o in piezas)
	tamano = valor_de_hoja(nombre, "tamano_textura", 2048)
	reempacar(piezas, nombre, tamano)
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
	print("  %s: %d -> %d triángulos, %d caras de tapa, textura de %d px" % (nombre, antes, despues, tapas, tamano))


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


# Solo al correrlo directo (esqueleto_blender.py importa sus funciones).
if __name__ == "__main__":
	main()
