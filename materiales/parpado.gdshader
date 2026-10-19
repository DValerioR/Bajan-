// Párpado de los personajes con cara animada: una copia de la piel sobre el ojo, del color de la
// piel. Con `cierre` en 0 no se ve; al subir a 1 va bajando desde arriba hasta tapar el ojo entero.
shader_type spatial;

uniform vec4 color_piel : source_color = vec4(0.9, 0.6, 0.4, 1.0);
// Altura (en coordenadas de la cabeza) de la orilla de arriba y de abajo del ojo.
uniform float tope = 0.1;
uniform float fondo = 0.0;
uniform float cierre = 0.0;
// Dónde va la línea de pestañas con el ojo cerrado (un poco abajo del centro del ojo).
uniform float linea = 0.05;
uniform float umbral = 0.05;
uniform float suavizado = 0.04;
uniform float relleno_sombra = 0.3;

varying float altura;

void vertex() {
	altura = VERTEX.y;
}

void fragment() {
	if (altura < mix(tope + 0.01, fondo, cierre)) {
		discard;
	}
	// Una raya oscura en la orilla del párpado mientras baja, y con el ojo cerrado una línea de
	// pestañas a media altura, como se dibuja un ojo cerrado en caricatura.
	float orilla = mix(tope + 0.01, fondo, cierre);
	bool raya = (altura - orilla < 0.004 && cierre > 0.05 && cierre < 0.85) || (cierre >= 0.85 && abs(altura - linea) < 0.0035);
	// El párpado un poco más oscuro que la piel, para que se lea como párpado.
	ALBEDO = raya ? vec3(0.12, 0.07, 0.06) : color_piel.rgb * 0.9;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float luz = smoothstep(umbral - suavizado, umbral + suavizado, ndl) * smoothstep(0.35, 0.65, ATTENUATION);
	DIFFUSE_LIGHT += mix(relleno_sombra, 1.0, luz) * LIGHT_COLOR / PI;
}
