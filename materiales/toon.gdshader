// Sombreado toon de Bajan!: luz en dos tonos con borde suave y un brillo de contorno.
// Lo aplica EstiloToon a partir del color de los materiales normales.
shader_type spatial;

uniform vec4 color_base : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_linear_mipmap, hint_default_white;
uniform bool usar_textura = false;
// Dónde cambia de sombra a luz (producto punto normal-luz) y qué tan suave es el corte.
uniform float umbral = 0.05;
uniform float suavizado = 0.04;
// Luz que recibe el lado en sombra (0 = solo luz ambiental).
uniform float relleno_sombra = 0.3;
// Brillo en el borde de las formas, del lado iluminado.
uniform float brillo_borde = 0.18;

void fragment() {
	vec4 color = color_base;
	if (usar_textura) {
		color *= texture(textura, UV);
	}
	ALBEDO = color.rgb;
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
