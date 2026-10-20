extends SceneTree
## Herramienta: deja las texturas de los personajes (modelos/personajes/*_albedo.jpg) con
## compresión de video de alta calidad (D46). Godot las importa sin compresión la primera vez;
## procesar_personajes.bat corre esto después de importar y vuelve a importar las que cambió.

const CARPETA := "res://modelos/personajes"


func _init() -> void:
	var cambiadas := 0
	for archivo in DirAccess.get_files_at(CARPETA):
		if not archivo.ends_with("_albedo.jpg.import"):
			continue
		var ruta := CARPETA.path_join(archivo)
		var texto := FileAccess.get_file_as_string(ruta)
		var nuevo := texto.replace("compress/mode=0", "compress/mode=2").replace("compress/high_quality=false", "compress/high_quality=true")
		if nuevo != texto:
			var f := FileAccess.open(ruta, FileAccess.WRITE)
			f.store_string(nuevo)
			f.close()
			cambiadas += 1
			print("  comprimida: ", archivo.trim_suffix(".import"))
	print("Texturas de personajes comprimidas: %d" % cambiadas)
	quit(0)
