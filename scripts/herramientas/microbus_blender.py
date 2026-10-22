# Herramienta (Blender): prepara el modelo del microbús de Tripo para usarlo como el exterior del camión
# (D60). El interior del juego no cambia: este modelo solo se ve por fuera.
#   - Separa sus partes sueltas: una llanta (la delantera de la puerta) sale aparte, centrada, para
#     usarla en las cuatro llantas del juego (que giran y dan vuelta); las otras tres se quitan.
#   - Quita lo que trae por dentro (tablero y volante), que chocaría con el interior del juego.
#   - Los vidrios (las caras con el azul del vidrio) salen aparte, en pedazos sueltos ("Vidrio1",
#     "Vidrio2"...; Tripo hace cada ventana de varios), con su propio material: en el juego son
#     transparentes (desde afuera se ve a la gente) y se rompen los de cerca de donde alguien sale
#     volando. La puerta delantera del lado de la
#     puerta se abre de verdad, para poder bajar.
#   - Lo acomoda a la medida del camión: la puerta delantera del modelo (encima de su llanta) cae en
#     la puerta del juego y su llanta trasera en la del juego; su techo queda un poco arriba del
#     techo del juego y su falda, justo arriba de las llantas (las paredes de abajo del juego se
#     esconden por fuera: desde adentro las tapa el forro).
# Tripo lo entrega mirando a -Y, de 1 m de largo, con las puertas del lado -X.
#
# Uso: blender --background --factory-startup --python scripts/herramientas/microbus_blender.py -- <fbx> <salida.glb>

import sys

import bmesh
import bpy
from mathutils import Vector

# Medidas del modelo de Tripo (coordenadas de Blender, como viene).
PUERTA_Y = (-0.372, -0.258)
PUERTA_Z = (0.155, 0.48)
LLANTA_DELANTERA_Y = -0.312
CUERPO_X = 0.223
CUERPO_Z = (0.091, 0.542)
# Del camión del juego (coordenadas de la carrocería, que está 0.3 m abajo del camión): la puerta
# (centro en z), el ancho que tiene que tapar, hasta dónde baja la falda y el techo.
PUERTA_JUEGO_Z = -3.15
LLANTA_TRASERA_JUEGO_Z = 2.6
LLANTA_TRASERA_Y = 0.3145
MEDIO_ANCHO = 1.56
FALDA = -0.15
TECHO = 2.55
RADIO_LLANTA = 0.45


def color_de(cara, uv, pixeles, ancho, alto):
	u = sum(l[uv].uv.x for l in cara.loops) / len(cara.loops)
	v = sum(l[uv].uv.y for l in cara.loops) / len(cara.loops)
	x = min(ancho - 1, max(0, int(u % 1.0 * ancho)))
	y = min(alto - 1, max(0, int(v % 1.0 * alto)))
	i = (y * ancho + x) * 4
	return pixeles[i], pixeles[i + 1], pixeles[i + 2]


def main():
	argumentos = sys.argv[sys.argv.index("--") + 1:]
	fbx, salida = argumentos[0], argumentos[1]
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=fbx)
	cuerpo = next(o for o in bpy.data.objects if o.type == "MESH")
	imagen = next(i for i in bpy.data.images if i.size[0] > 0)
	ancho, alto = imagen.size
	pixeles = list(imagen.pixels)

	bm = bmesh.new()
	bm.from_mesh(cuerpo.data)
	bm.transform(cuerpo.matrix_world)
	uv = bm.loops.layers.uv.active

	# Partes sueltas.
	bm.verts.ensure_lookup_table()
	visto = set()
	partes = []
	for v in bm.verts:
		if v.index in visto:
			continue
		pila = [v]
		visto.add(v.index)
		parte = []
		while pila:
			a = pila.pop()
			parte.append(a)
			for e in a.link_edges:
				b = e.other_vert(a)
				if b.index not in visto:
					visto.add(b.index)
					pila.append(b)
		partes.append(parte)

	llanta = None
	quitar = set()
	for parte in partes:
		xs = [v.co.x for v in parte]
		ys = [v.co.y for v in parte]
		zs = [v.co.z for v in parte]
		# Las llantas: tocan el piso y miden unos 0.19 de alto.
		if min(zs) < 0.01 and 0.17 < max(zs) < 0.21 and len(parte) > 200:
			if llanta is None and max(xs) < 0 and min(ys) < LLANTA_DELANTERA_Y < max(ys):
				llanta = {v.index for v in parte}
			quitar.update(parte)
			continue
		# Lo de adentro: piezas que no tocan la orilla del cuerpo (tablero, volante).
		if max(abs(x) for x in xs) < CUERPO_X - 0.05 and min(zs) > 0.2 and max(zs) < 0.42 and min(ys) > -0.45:
			quitar.update(parte)
	# La llanta va en su propia malla: una copia con nada más ella.
	bm_llanta = bm.copy()
	bm_llanta.verts.ensure_lookup_table()
	bmesh.ops.delete(bm_llanta, geom=[v for v in bm_llanta.verts if v.index not in llanta], context="VERTS")
	# Los vidrios aparte (material 1) y el hueco de la puerta delantera del lado -X.
	caras_fuera = set()
	caras_vidrio = []
	for f in bm.faces:
		if any(v in quitar for v in f.verts):
			caras_fuera.add(f)
			continue
		r, g, b = color_de(f, uv, pixeles, ancho, alto)
		c = f.calc_center_median()
		vidrio = b > r + 0.08 and b > 0.25
		puerta = f.normal.x < -0.5 and PUERTA_Y[0] <= c.y <= PUERTA_Y[1] and PUERTA_Z[0] <= c.z <= PUERTA_Z[1]
		if puerta:
			caras_fuera.add(f)
		elif vidrio:
			caras_vidrio.append(f)
	for f in caras_vidrio:
		f.material_index = 1
	bmesh.ops.delete(bm, geom=list(caras_fuera), context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

	# A la medida del camión. Se escribe en Blender lo que el exportador de glTF pasa a Godot como
	# (x, y, z) del juego: Godot (x, y, z) = Blender (x, z, -y). El modelo mira a -Y y el juego a -Z
	# con la puerta a la derecha (+X), así que se voltea: x del juego = -x del modelo.
	largo = (LLANTA_TRASERA_JUEGO_Z - PUERTA_JUEGO_Z) / (LLANTA_TRASERA_Y - sum(PUERTA_Y) / 2.0)
	corrimiento = PUERTA_JUEGO_Z - sum(PUERTA_Y) / 2.0 * largo
	alto_escala = (TECHO - FALDA) / (CUERPO_Z[1] - CUERPO_Z[0])
	base = FALDA - CUERPO_Z[0] * alto_escala
	ancho_escala = MEDIO_ANCHO / CUERPO_X

	def al_juego(p):
		gx = -p.x * ancho_escala
		gy = p.z * alto_escala + base
		gz = p.y * largo + corrimiento
		return Vector((gx, -gz, gy))

	for v in bm.verts:
		v.co = al_juego(v.co)
	bm.normal_update()
	malla = bpy.data.meshes.new("Carroceria")
	bm.to_mesh(malla)
	bm.free()
	exterior = bpy.data.objects.new("Exterior", malla)
	exterior.data.materials.append(cuerpo.data.materials[0])
	exterior.data.materials.append(bpy.data.materials.new("Vidrio"))
	bpy.context.scene.collection.objects.link(exterior)

	# La llanta, centrada y del radio del juego (con su cara hacia +X del juego).
	bm = bm_llanta
	puntos = [v.co for v in bm.verts]
	minimo = Vector((min(p.x for p in puntos), min(p.y for p in puntos), min(p.z for p in puntos)))
	maximo = Vector((max(p.x for p in puntos), max(p.y for p in puntos), max(p.z for p in puntos)))
	centro = (minimo + maximo) / 2.0
	escala = RADIO_LLANTA / ((maximo.z - minimo.z) / 2.0)
	for v in bm.verts:
		d = (v.co - centro) * escala
		v.co = Vector((-d.x, -d.y, d.z))
	bm.normal_update()
	malla_llanta = bpy.data.meshes.new("Llanta")
	bm.to_mesh(malla_llanta)
	bm.free()
	rueda = bpy.data.objects.new("Llanta", malla_llanta)
	rueda.data.materials.append(cuerpo.data.materials[0])
	bpy.context.scene.collection.objects.link(rueda)

	bpy.data.objects.remove(cuerpo)
	# Los vidrios: se sacan del exterior y cada ventana (parte suelta) queda como objeto aparte.
	bpy.context.view_layer.objects.active = exterior
	for o in bpy.data.objects:
		o.select_set(o == exterior)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="DESELECT")
	exterior.active_material_index = 1
	bpy.ops.object.material_slot_select()
	bpy.ops.mesh.separate(type="SELECTED")
	bpy.ops.object.mode_set(mode="OBJECT")
	vidrios = [o for o in bpy.data.objects if o.type == "MESH" and o not in (exterior, rueda)]
	if vidrios:
		# Se cortan los vidrios entre caras que ven a lados distintos (frente, atrás, izquierda,
		# derecha, arriba, abajo) y, los de los lados, en tramos: Tripo une el parabrisas, las
		# ventanas y el vidrio de atrás en una sola tira.
		cristal = vidrios[0]
		bmv = bmesh.new()
		bmv.from_mesh(cristal.data)

		def lado(f):
			n = f.normal
			if abs(n.z) >= abs(n.x) and abs(n.z) >= abs(n.y):
				return 4 if n.z < 0 else 5
			if abs(n.y) >= abs(n.x):
				return 0 if n.y < 0 else 1
			return 2 if n.x < 0 else 3

		def grupo(f):
			# El parabrisas y el vidrio de atrás, enteros; los de los lados (y las orillas de arriba y
			# abajo), en tramos a lo largo del camión, para que no quede un vidrio que lo cruce todo.
			k = lado(f)
			if k in (0, 1):
				return (k,)
			return (k, round(f.calc_center_median().y / 0.06))

		bmesh.ops.split_edges(bmv, edges=[e for e in bmv.edges if len(e.link_faces) == 2 and grupo(e.link_faces[0]) != grupo(e.link_faces[1])])
		bmv.to_mesh(cristal.data)
		bmv.free()
		bpy.context.view_layer.objects.active = cristal
		for o in bpy.data.objects:
			o.select_set(o == cristal)
		bpy.ops.mesh.separate(type="LOOSE")
	vidrios = [o for o in bpy.data.objects if o.type == "MESH" and o not in (exterior, rueda)]
	vidrios = [o for o in bpy.data.objects if o.type == "MESH" and o not in (exterior, rueda)]
	vidrios.sort(key=lambda o: (sum((o.matrix_world @ v.co).y for v in o.data.vertices) / max(len(o.data.vertices), 1)))
	for k, o in enumerate(vidrios):
		o.name = "Vidrio%d" % (k + 1)
		o.data.materials.clear()
		o.data.materials.append(bpy.data.materials["Vidrio"])
	exterior.data.materials.pop(index=1)
	for o in list(bpy.data.objects):
		o.select_set(o.type == "MESH")
	bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
	print("listo: %s (largo x%.2f, alto x%.2f, ancho x%.2f; llanta x%.2f; %d vidrios)" % (salida, largo, alto_escala, ancho_escala, escala, len(vidrios)))


main()
