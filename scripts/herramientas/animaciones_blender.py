# Herramienta (Blender): saca las animaciones de un FBX de Tripo (rig estilo Mixamo) para el juego.
# Cada animación queda en animaciones/<nombre>.json y sirve para cualquier personaje (D53): no
# guarda la pose de este modelo sino cuánto gira cada uno de los 11 huesos del juego respecto a la
# pose T, en los ejes de la figura de Godot (x: a su derecha, y: arriba, z: hacia atrás).
#   {"fps": 30, "huesos": {hueso: [[x, y, z, w] por cuadro]}, "en_t": {hueso: [x, y, z]},
#    "cadera_y": [subida de la cadera por cuadro, como fracción de la estatura]}
# `en_t` es hacia dónde apunta cada hueso en la pose T (brazos y piernas): el juego lo compara con
# el reposo de cada personaje (los brazos caídos) para que la animación quede igual en todos.
#
# Uso: blender --background --factory-startup --python scripts/herramientas/animaciones_blender.py -- <fbx> <carpeta>

import json
import os
import sys

import bpy
from mathutils import Matrix

# Hueso del juego -> (hueso de Tripo, hueso hacia donde apunta en la pose T).
MAPA = {
	"Cadera": ("Hips", "Spine"),
	"Torso": ("Spine2", "Neck"),
	"Cabeza": ("Head", "HeadTop_End"),
	"BrazoIzquierdo": ("LeftArm", "LeftForeArm"),
	"AntebrazoIzquierdo": ("LeftForeArm", "LeftHand"),
	"BrazoDerecho": ("RightArm", "RightForeArm"),
	"AntebrazoDerecho": ("RightForeArm", "RightHand"),
	"PiernaIzquierda": ("LeftUpLeg", "LeftLeg"),
	"PantorrillaIzquierda": ("LeftLeg", "LeftFoot"),
	"PiernaDerecha": ("RightUpLeg", "RightLeg"),
	"PantorrillaDerecha": ("RightLeg", "RightFoot"),
}
# Nombres en el juego de las animaciones de Tripo (las demás se quedan con el suyo).
NOMBRES = {"afraid": "susto", "agree": "asentir", "angry": "enojo", "box": "pelear"}
# De Blender (mirando a -Y, como entrega Tripo) a la figura de Godot (mirando a -Z): se voltea
# sobre Z y se pasa a Y arriba. (x, y, z) -> (-x, z, y).
A_GODOT = Matrix(((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)))


def nombre_juego(accion):
	base = accion.name.split("|")[-1].split(".")[0]
	for ingles, espanol in NOMBRES.items():
		if base.startswith(ingles):
			return espanol
	return base


def main():
	argumentos = sys.argv[sys.argv.index("--") + 1:]
	fbx, carpeta = argumentos[0], argumentos[1]
	os.makedirs(carpeta, exist_ok=True)
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=fbx)
	rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	cuerpo = next(o for o in bpy.data.objects if o.type == "MESH")
	escena = bpy.context.scene
	huesos = {pb.name.split(":")[-1]: pb for pb in rig.pose.bones}
	acciones = list(bpy.data.actions)
	if rig.animation_data is None:
		rig.animation_data_create()

	# Pose T (sin animación): giros y puntas de reposo, y la estatura.
	rig.animation_data.action = None
	for pb in rig.pose.bones:
		pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
		pb.rotation_euler = (0.0, 0.0, 0.0)
		pb.location = (0.0, 0.0, 0.0)
	bpy.context.view_layer.update()
	mundo = rig.matrix_world
	reposo = {n: (mundo @ pb.matrix).to_3x3().normalized() for n, pb in huesos.items()}
	cadera_reposo = (mundo @ huesos["Hips"].matrix).translation.z
	alturas = [(cuerpo.matrix_world @ v.co).z for v in cuerpo.data.vertices]
	estatura = max(alturas) - min(alturas)
	en_t = {}
	for juego, (tripo, punta) in MAPA.items():
		d = (mundo @ huesos[punta].head) - (mundo @ huesos[tripo].head)
		d = (A_GODOT @ d).normalized()
		en_t[juego] = [round(d.x, 5), round(d.y, 5), round(d.z, 5)]

	for accion in acciones:
		rig.animation_data.action = accion
		if hasattr(rig.animation_data, "action_slot") and len(accion.slots) > 0:
			rig.animation_data.action_slot = accion.slots[0]
		inicio, fin = int(accion.frame_range[0]), int(accion.frame_range[1])
		datos = {"fps": escena.render.fps / escena.render.fps_base, "huesos": {n: [] for n in MAPA}, "en_t": en_t, "cadera_y": []}
		for cuadro in range(inicio, fin + 1):
			escena.frame_set(cuadro)
			for juego, (tripo, _punta) in MAPA.items():
				giro = (mundo @ huesos[tripo].matrix).to_3x3().normalized() @ reposo[tripo].inverted()
				q = (A_GODOT @ giro @ A_GODOT.transposed()).to_quaternion()
				datos["huesos"][juego].append([round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)])
			subida = (mundo @ huesos["Hips"].matrix).translation.z - cadera_reposo
			datos["cadera_y"].append(round(subida / estatura, 5))
		nombre = nombre_juego(accion)
		with open(os.path.join(carpeta, nombre + ".json"), "w", encoding="utf-8") as archivo:
			json.dump(datos, archivo, separators=(",", ":"))
		print("  %s (%s): %d cuadros" % (nombre, accion.name, fin - inicio + 1))


main()
