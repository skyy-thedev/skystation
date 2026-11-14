# Roteiro da Fase 8 — mais PS3, jogos em segundo plano e SkyNetwork

## Já entregue (8.0)
- Menu Home dentro do jogo no estilo XMB: Jogo, Troféus, Amigos, Ajustes e Energia.
- Troféus conferidos a cada minuto durante a partida, com o som tocando na hora.

## O limite atual: o compositor `cage`
O SkyStation roda dentro do **cage**, um compositor "quiosque": ele mostra **uma janela por vez**,
sempre a mais nova. Por isso:
- o menu Home precisa congelar o jogo e cobrir a tela inteira com uma foto dele;
- um aviso pequeno ("Troféu de prata!") **não consegue** aparecer por cima do jogo rodando, porque o
  cage não tem o protocolo de camadas (wlr-layer-shell) que avisos e barras usam;
- voltar ao menu principal com o jogo aberto em segundo plano não dá no cage 0.2. O cage 0.3
  (abril de 2026) passou a aceitar que um programa externo escolha a janela da frente
  (protocolo wlr-foreign-toplevel-management). Se o Arch do console já tiver o cage 0.3
  (`cage -v`), dá para testar o segundo plano sem trocar de compositor; os avisos por cima do jogo
  continuam precisando do gamescope.

## 8.1 — trocar o cage pelo gamescope (o compositor do Steam Deck)
O gamescope foi feito exatamente para isso: o Steam do Steam Deck roda por cima dos jogos com ele.
- **Avisos por cima do jogo** (troféus, controle conectado, bateria fraca, mensagens de amigos):
  janela de overlay com o atributo `GAMESCOPE_EXTERNAL_OVERLAY`, sem pausar o jogo.
- **Jogo em segundo plano**: o launcher continua aberto e o gamescope escolhe qual janela aparece
  (`GAMESCOPE_FOCUSED_APP`). Home → volta ao menu principal com o jogo pausado atrás; "Continuar"
  no topo da categoria Jogos traz o jogo de volta. Fechar só quando o jogador pedir.
- Bônus: limite de FPS, escala FSR e HDR já vêm prontos.
- Risco: o gamescope é mais exigente com o driver de vídeo. A troca entra com plano B: se o gamescope
  falhar ao abrir, a sessão volta sozinha para o cage.
- Precisa de teste no notebook antes de virar padrão.

## 8.2 — SkyNetwork (a "PSN" do SkyStation)
Objetivo: os 4 consoles (você + 3 amigos) veem quem está online, o que cada um está jogando e trocam
mensagens.

**Servidor:** um app Next.js na Vercel + Postgres (Neon) com Prisma, a mesma stack da Skyz.
O plano gratuito aguenta folgado 4 consoles.

**Tabelas:**
- `Jogador`: id, apelido (o nome do perfil), cor, token do console, criado_em
- `Amizade`: jogador_a, jogador_b, status (pendente/aceita)
- `Presenca`: jogador, status (online/jogando/ausente), jogo, sistema, desde, visto_em
- `Mensagem`: de, para, texto, enviada_em, lida_em
- `TrofeuGanho` (depois): jogador, trofeu, ganho_em — para mostrar "Fulano ganhou um troféu"

**No console:** um serviço `sky-net` (Python, segundo plano):
- a cada 30 s, envia a presença (o `sky-run` já sabe qual jogo está aberto: `game.id` / `game.title`);
- busca mensagens novas e a presença dos amigos; grava em `$XDG_RUNTIME_DIR/skystation/net.json`;
- o launcher e o menu Home leem esse arquivo (categoria **Amigos** deixa de ser "em breve");
- mensagem nova → aviso com som (e, com o gamescope, aparece por cima do jogo).

**Escrever mensagens com o controle:** teclado na tela + mensagens rápidas prontas
("Bora jogar?", "GG!", "Entra no Wi-Fi") — e a Central web do celular para textos longos.

**Entrar na rede:** em Sistema → SkyNetwork, o console gera um código de 6 letras; você aceita o
amigo pelo código. O token fica só no console, sem senha para digitar.

**Privacidade:** cada um pode ficar "invisível" (não envia o jogo atual).

## Ordem sugerida
1. Testar o menu Home novo e o troféu ao vivo no notebook (8.0).
2. SkyNetwork só com presença ("quem está jogando o quê") — dá para fazer sem mexer no compositor.
3. Mensagens.
4. Gamescope (8.1), que destrava os avisos por cima do jogo e o segundo plano.
