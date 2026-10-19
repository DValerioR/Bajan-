// Toon de la cabeza y la mandíbula de los personajes con cara animada: igual que toon.gdshader,
// pero también dibuja las caras de atrás, en oscuro. Así, al abrirse la mandíbula (que es una pieza
// aparte), por el corte se ve el interior de la boca y no un hueco.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color_base : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_linear_mipmap, hint_default_white;
uniform bool usar_textura = false;
uniform vec4 color_interior : source_color = vec4(0.32, 0.07, 0.08, 1.0);
uniform float umbral = 0.05;
uniform float suavizado = 0.04;
uniform float relleno_sombra = 0.3;
uniform float brillo_borde = 0.18;

void fragment() {
	if (!FRONT_FACING) {
		ALBEDO = color_interior.rgb;
		NORMAL = -NORMAL;
	} else {
		vec4 color = color_base;
		if (usar_textura) {
			color *= texture(textura, UV);
		}
		ALBEDO = color.rgb;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float sombra_proyectada = smoothstep(0.35, 0.65, ATTENUATION);
	float luz = smoothstep(umbral - suavizado, umbral + suavizado, ndl) * sombra_proyectada;
	float borde = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * brillo_borde * luz;
	DIFFUSE_LIGHT += (mix(relleno_sombra, 1.0, luz) + borde) * LIGHT_COLOR / PI;
}
