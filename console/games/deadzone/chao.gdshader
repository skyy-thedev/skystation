shader_type canvas_item;
// Chão e paredes sem "papel de parede": a mesma textura é lida duas vezes (a segunda girada e em outra
// escala) e um ruído grande do mundo decide qual das duas aparece em cada lugar. Como as duas grades de
// repetição não batem, o olho não acha mais o padrão. Por cima, manchas largas de claro/escuro e de
// calor/frio, como sol, sujeira e umidade de verdade.

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform float mistura = 1.0;     // 0 = textura pura (para depurar)

varying vec2 mundo;
varying vec4 cor_vertice;   // o "mod" de draw_texture_rect (no fragment, COLOR já vem multiplicado pela textura)

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	cor_vertice = COLOR;
}

vec2 girar(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(TEXTURE, girar(UV, 2.1) * 0.79 + vec2(0.37, 0.71));
	float n = texture(ruido, mundo / 640.0).r;
	vec4 c = mix(a, b, smoothstep(0.36, 0.64, n) * mistura);
	// macro: regiões mais claras e mais escuras, bem maiores que uma repetição
	float macro = texture(ruido, mundo / 2600.0 + vec2(0.5, 0.25)).r;
	c.rgb *= mix(1.0, mix(0.74, 1.14, macro), mistura);
	// algumas regiões puxam para o quente (sol, ferrugem), outras para o frio (sombra, umidade)
	float q = texture(ruido, mundo / 1700.0 + vec2(0.21, 0.83)).r - 0.5;
	c.rgb *= 1.0 + vec3(0.08, 0.02, -0.08) * q * 2.0 * mistura;
	COLOR = c * cor_vertice;
}
