// Contorno grueso por "casco invertido": dibuja la cara trasera de la malla un poco inflada.
// En cajas se infla por eje (modo_caja) para que las esquinas no se abran. Los personajes guardan
// una normal suavizada en el color del vértice (normal_en_color) para que no se abra en las costuras.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 color_contorno : source_color = vec4(0.09, 0.06, 0.07, 1.0);
uniform float grosor = 0.035;
uniform bool modo_caja = false;
uniform bool normal_en_color = false;

void vertex() {
	if (modo_caja) {
		VERTEX += sign(VERTEX) * grosor;
	} else if (normal_en_color) {
		VERTEX += normalize(COLOR.rgb * 2.0 - 1.0) * grosor;
	} else {
		VERTEX += NORMAL * grosor;
	}
}

void fragment() {
	ALBEDO = color_contorno.rgb;
}
