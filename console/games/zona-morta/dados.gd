extends RefCounted
## Tudo que é "tabela" do jogo: itens, armas, receitas e o que se acha em cada lugar.
## Mexer no equilíbrio do jogo = mexer nos números daqui.

const ITENS := {
	"enlatado": {"nome": "Enlatado", "tipo": "comida", "fome": 35},
	"salgadinho": {"nome": "Salgadinho", "tipo": "comida", "fome": 15},
	"carne_crua": {"nome": "Carne crua", "tipo": "comida", "fome": 10, "enjoo": 12, "dica": "Asse numa fogueira"},
	"carne_assada": {"nome": "Carne assada", "tipo": "comida", "fome": 55, "cura": 10},
	"agua": {"nome": "Garrafa d'água", "tipo": "comida", "fome": 8, "cura": 4},
	"bandagem": {"nome": "Bandagem", "tipo": "cura", "cura": 35},
	"kit_medico": {"nome": "Kit médico", "tipo": "cura", "cura": 100},
	"madeira": {"nome": "Madeira", "tipo": "material"},
	"pano": {"nome": "Pano", "tipo": "material"},
	"sucata": {"nome": "Sucata", "tipo": "material"},
	"garrafa": {"nome": "Garrafa vazia", "tipo": "material"},
	"pilhas": {"nome": "Pilhas", "tipo": "luz", "dica": "Recarrega a lanterna"},
	"tocha": {"nome": "Tocha", "tipo": "luz", "dica": "Acende e ilumina em volta (sem pilha)"},
	"galao": {"nome": "Galão", "tipo": "ferramenta", "dica": "Leva até 10 L: encha no posto ou num tanque, abasteça um carro"},
	"molotov": {"nome": "Coquetel molotov", "tipo": "arremesso", "dica": "L1 arremessa"},
	"balas_9mm": {"nome": "Balas 9mm", "tipo": "municao"},
	"cartuchos": {"nome": "Cartuchos 12", "tipo": "municao"},
	"balas_rifle": {"nome": "Balas de rifle", "tipo": "municao"},
}

## corpo = arma branca. barulho = raio (px) em que os zumbis ouvem.
const ARMAS := {
	"punhos": {"nome": "Punhos", "corpo": true, "dano": 9, "alcance": 46, "cad": 0.40, "barulho": 60, "folego": 6},
	"faca": {"nome": "Faca", "corpo": true, "dano": 22, "alcance": 52, "cad": 0.30, "barulho": 40, "folego": 7},
	"taco": {"nome": "Taco", "corpo": true, "dano": 28, "alcance": 64, "cad": 0.50, "barulho": 110, "folego": 12},
	"machado": {"nome": "Machado", "corpo": true, "dano": 36, "alcance": 64, "cad": 0.65, "barulho": 110, "folego": 15, "corta": true},
	"pistola": {"nome": "Pistola", "municao": "balas_9mm", "pente": 8, "dano": 42, "alcance": 650, "cad": 0.30,
		"barulho": 720, "recarga": 1.1, "chumbos": 1, "abertura": 0.0},
	"espingarda": {"nome": "Espingarda", "municao": "cartuchos", "pente": 5, "dano": 22, "alcance": 380, "cad": 0.85,
		"barulho": 950, "recarga": 2.0, "chumbos": 6, "abertura": 0.30},
	"rifle": {"nome": "Rifle", "municao": "balas_rifle", "pente": 10, "dano": 90, "alcance": 950, "cad": 0.55,
		"barulho": 1150, "recarga": 1.8, "chumbos": 1, "abertura": 0.0},
}

const RECEITAS := [
	{"faz": "tocha", "q": 1, "usa": {"madeira": 1, "pano": 1}},
	{"faz": "bandagem", "q": 1, "usa": {"pano": 2}},
	{"faz": "fogueira", "q": 1, "usa": {"madeira": 3}, "colocar": true, "dica": "Ilumina, espanta o frio e assa carne"},
	{"faz": "molotov", "q": 1, "usa": {"garrafa": 1, "pano": 1}, "gasolina": 2},
	{"faz": "faca", "q": 1, "usa": {"sucata": 2, "pano": 1}, "arma": true},
	{"faz": "machado", "q": 1, "usa": {"sucata": 3, "madeira": 2}, "arma": true},
]

## loot: [chance, item, mín, máx]. "arma:x" dá a arma. Munição é escassa de propósito.
const LOOT := {
	"armario": [[0.40, "pano", 1, 2], [0.22, "enlatado", 1, 1], [0.15, "salgadinho", 1, 2], [0.14, "bandagem", 1, 1],
		[0.18, "garrafa", 1, 1], [0.10, "pilhas", 1, 1], [0.12, "agua", 1, 1], [0.05, "balas_9mm", 1, 3],
		[0.04, "arma:taco", 1, 1], [0.04, "arma:faca", 1, 1]],
	"geladeira": [[0.45, "carne_crua", 1, 2], [0.35, "enlatado", 1, 2], [0.25, "agua", 1, 2], [0.15, "salgadinho", 1, 1]],
	"prateleira": [[0.45, "enlatado", 1, 2], [0.35, "salgadinho", 1, 2], [0.25, "agua", 1, 1], [0.15, "garrafa", 1, 2],
		[0.12, "pilhas", 1, 1], [0.10, "pano", 1, 1]],
	"porta_malas": [[0.45, "sucata", 1, 2], [0.18, "galao", 1, 1], [0.15, "pano", 1, 1], [0.08, "balas_9mm", 1, 2],
		[0.06, "arma:machado", 1, 1], [0.10, "enlatado", 1, 1], [0.08, "agua", 1, 1]],
	"viatura": [[0.45, "balas_9mm", 2, 5], [0.28, "cartuchos", 1, 3], [0.12, "arma:espingarda", 1, 1],
		[0.15, "bandagem", 1, 1], [0.12, "pilhas", 1, 1]],
	"arsenal": [[0.55, "balas_9mm", 3, 7], [0.40, "cartuchos", 2, 4], [0.22, "balas_rifle", 2, 5],
		[0.18, "arma:espingarda", 1, 1], [0.12, "arma:rifle", 1, 1], [0.12, "arma:pistola", 1, 1], [0.18, "kit_medico", 1, 1]],
	"ferramentas": [[0.30, "arma:machado", 1, 1], [0.50, "sucata", 1, 3], [0.22, "galao", 1, 1], [0.20, "pano", 1, 1]],
}


static func nome(id: String) -> String:
	if id.begins_with("arma:"):
		return ARMAS[id.substr(5)]["nome"]
	if ITENS.has(id):
		return ITENS[id]["nome"]
	if id == "fogueira":
		return "Fogueira"
	if ARMAS.has(id):
		return ARMAS[id]["nome"]
	return id


static func sortear(tabela: String, rng: RandomNumberGenerator) -> Array:
	## devolve [[item, q], …]; pode vir vazio (nem toda gaveta tem alguma coisa)
	var achou: Array = []
	for l in LOOT.get(tabela, []):
		if rng.randf() < l[0]:
			achou.append([l[1], rng.randi_range(l[2], l[3])])
	return achou
