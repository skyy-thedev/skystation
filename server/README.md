# SkyNetwork — o servidor do SkyStation

Um app Next.js que os consoles acessam pela internet. Faz duas coisas:

- **SkyCloud (Fase 9.4):** saves na nuvem, por perfil e por jogo, com 5 versões guardadas.
- **SkyNetwork (Fase 10):** amigos por código, quem está jogando o quê, mensagens, convites e troféus.

Stack: Next.js 16 + Prisma 7 + Postgres (Neon) na Vercel; os arquivos de save ficam num
armazenamento compatível com S3 (Cloudflare R2). Tudo cabe nos planos gratuitos para 4 consoles.

## Colocar no ar (uma vez)

1. **Vercel:** New Project → importe `skyy-thedev/skystation` → em **Root Directory** escolha `server`.
2. **Banco:** no projeto, aba Storage → Create Database → **Neon**. Ele preenche `DATABASE_URL` e
   `DATABASE_URL_UNPOOLED` sozinho. As tabelas são criadas no deploy (`prisma migrate deploy`).
3. **Saves (R2):** no painel da Cloudflare → R2 → crie o bucket `skycloud` → Manage API Tokens →
   token com permissão *Object Read & Write* nesse bucket. Anote o endpoint, o Access Key ID e o Secret.
4. **Variáveis** (Settings → Environment Variables), conforme o `.env.example`:
   `SKY_CONVITE`, `CRON_SECRET`, `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`
   (e `S3_REGION=auto`).
5. **Deploy.** Abra `https://<seu-projeto>.vercel.app/api/saude`: deve responder `"ok": true` e
   `"saves": true`.

Sem o passo 3 o servidor funciona do mesmo jeito para amigos, presença e mensagens; só as rotas de
save respondem "ainda não configurado".

## Rodar no PC

```bash
cd server
cp .env.example .env        # preencha DATABASE_URL e SKY_CONVITE
npm install
npm run db:migrar
npm run dev                 # http://localhost:3000
npm run teste               # em outro terminal: passa por todas as rotas
```

O mesmo teste roda sozinho no GitHub a cada mudança em `server/` (`.github/workflows/servidor.yml`).

## Como o console conversa com o servidor

Todas as rotas respondem JSON. Erros vêm como `{ "erro": "codigo", "mensagem": "texto para a tela" }`.

| Cabeçalho | Quando |
|---|---|
| `Authorization: Bearer <token>` | sempre, menos no registro |
| `X-Perfil: p1` | nas rotas de um jogador (o id do perfil no `sky-perfis`) |

### Primeiro acesso

```bash
# 1. registra o console (o token só aparece AGORA: guarde em ~/.config/skystation/rede.json)
curl -X POST $URL/api/consoles -H 'Content-Type: application/json' \
     -d '{"nome":"SkyStation do Sky","convite":"<SKY_CONVITE>"}'

# 2. envia os perfis do console; cada um ganha um código de amigo de 6 letras
curl -X PUT $URL/api/perfis -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
     -d '{"perfis":[{"localId":"p1","apelido":"Sky","cor":"#4fd1ff"}]}'
```

### Rotas

| Rota | O que faz |
|---|---|
| `GET /api/saude` | servidor e banco no ar? saves configurados? |
| `POST /api/consoles` | registra um console (precisa do convite) e devolve o token |
| `GET /api/eu` · `DELETE /api/eu` | confere o token e lista os perfis · remove o console da rede |
| `PUT /api/perfis` | cria/atualiza os perfis (apelido, cor, `invisivel`) |
| **Saves** | |
| `GET /api/saves` | os saves do perfil na nuvem (versão, hash, tamanho, de qual console) |
| `POST /api/saves/enviar` | passo 1 do envio: devolve `igual`, um endereço para o `PUT`, ou `409 conflito` |
| `POST /api/saves/confirmar` | passo 2: confere se o arquivo chegou inteiro e torna a versão atual |
| `GET /api/saves/baixar?sistema=&jogoId=[&versao=]` | endereço temporário para baixar |
| `GET /api/saves/versoes?sistema=&jogoId=` | as versões guardadas (para voltar atrás) |
| `DELETE /api/saves?sistema=&jogoId=` | apaga o save do jogo da nuvem |
| **Rede** | |
| `POST /api/sync` | **a chamada de 30 em 30 s**: envia a presença, recebe amigos, pedidos, mensagens e troféus |
| `POST /api/presenca` | avisa na hora que abriu/fechou um jogo |
| `POST /api/amigos` | pede amizade pelo código |
| `POST /api/amigos/:id/aceitar` · `DELETE /api/amigos/:id` | aceita · recusa, cancela ou desfaz |
| `POST /api/mensagens` · `GET /api/mensagens?com=` | envia mensagem ou convite · histórico da conversa |
| `POST /api/mensagens/lidas` | marca como lidas |
| `POST /api/trofeus` · `GET /api/trofeus[?perfil=]` | registra troféus · lista os meus ou os de um amigo |

### O sync

```jsonc
// POST /api/sync
{ "presenca": { "status": "jogando", "jogoId": "ps2-gow2", "jogo": "God of War II", "sistema": "ps2" },
  "desde": "<o campo agora da resposta anterior>" }

// resposta
{ "agora": "2026-11-17T01:38:05.219Z",
  "eu": { "id": "…", "apelido": "Sky", "codigo": "K7M2QX", "invisivel": false },
  "amigos": [{ "amizadeId": "…", "id": "…", "apelido": "Bart", "cor": "#ff7a9c",
               "status": "jogando", "jogo": "Metal Gear Rising", "sistema": "x360", "desde": "…" }],
  "pedidosRecebidos": [], "pedidosEnviados": [],
  "mensagens": [], "naoLidas": 0, "trofeus": [] }
```

`status` de um amigo: `online`, `jogando`, `ausente` ou `offline` (sem sinal há 90 s, ou invisível).
`mensagens` e `trofeus` podem repetir itens da chamada anterior: ignore os `id` já vistos.

### Enviar um save

1. O console compacta o save **daquele jogo** e calcula o sha256.
2. `POST /api/saves/enviar` com `{ sistema, jogoId, hash, tamanho, baseVersao }`, onde `baseVersao`
   é a versão da nuvem que este console baixou ou enviou por último (0 se nunca).
3. Resposta `enviar` → `PUT` do arquivo no `url` recebido → `POST /api/saves/confirmar`.
4. Resposta `409 conflito` → outro console enviou um save diferente nesse meio-tempo. Mostre as duas
   opções ao jogador: baixar o da nuvem, ou reenviar com `"forcar": true`.

O arquivo vai direto do console para o armazenamento, sem passar pelo servidor: a Vercel limita o
corpo de uma requisição a 4,5 MB, e um save de PS3 passa disso com facilidade.

## Segurança

- O token nasce no registro e fica só no console; o banco guarda o hash (sha256).
- Só entra na rede quem tem o código de convite, e há um teto de consoles (`SKY_MAX_CONSOLES`).
- Cada console pode fazer até 120 requisições por minuto.
- Um perfil só enxerga os próprios saves; mensagens e troféus, só entre amigos aceitos.
- Mensagens com mais de 90 dias e envios de save abandonados são apagados uma vez por dia.
