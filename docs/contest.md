# Estratégia e conformidade — InterSystems Programming Contest #48

**Contest:** Build Your Own Management Portal
**Duração:** 14/09/2026 a 04/10/2026. Prêmio total: 12.000 dólares.
**Submissão individual.** Análise feita sobre o anúncio na Developer Community e sobre a página do contest no Open Exchange, que **não dizem a mesma coisa**.

---

## 1. O achado mais importante desta análise

O anúncio na Developer Community lista a tarefa e os requisitos gerais. A página do contest no Open Exchange acrescenta **os critérios de julgamento**, que o anúncio não menciona:

> As submissões serão julgadas por **Complexity, Clarity of Instructions, Developer Experience, Applicability e Usability**.

Cinco critérios. Leia de novo quais são dois deles: **clareza das instruções** e **experiência do desenvolvedor**. Isso significa que **README e instalação valem dois quintos do julgamento dos experts**, e não são acabamento de última hora. Uma aplicação tecnicamente superior com README confuso perde para uma aplicação equivalente com instalação impecável.

Tradução direta para decisão de projeto:

| Critério | O que o júri está medindo | Onde isso é atacado |
|---|---|---|
| Complexity | Profundidade real, não contagem de telas | Cobertura integral dos 273 endpoints, grafo de permissões, análise de impacto, provedores nativos de log |
| Clarity of Instructions | README e passos de instalação | Um comando, sem edição de arquivo, porta em conflito documentada |
| Developer Experience | Quanto atrito o avaliador encontra | Dados de demonstração no primeiro acesso, erro de compilação legível no log do contêiner |
| Applicability | Alguém usaria isso de verdade | Modo seguro, dry-run, autoproteção, degradação graciosa |
| Usability | Facilidade de uso da interface | Paleta, grafo, lista mais inspetor, dois temas, acessibilidade |

**Reserve dia e meio para README, vídeo e instalação.** Nos critérios publicados, isso rende mais do que um sétimo domínio.

---

## 2. Requisitos obrigatórios

### 2.1 Escopo funcional

Seis eixos, e a moderação foi explícita nos comentários do anúncio, em resposta ao Mark OReilly, de que a aplicação precisa implementar **todos os seis**, não um subconjunto:

1. Manage web apps and explore REST APIs
2. Permission management
3. Security and Secrets management (with wallet, x509 creds, OAuth setup, **etc**)
4. Task management
5. Operating system management (processes, disks, CPU, memory, devices, **etc**)
6. All the logs, what's being reported to the user from various sub-systems

**Leitura adotada do "etc": cobertura integral do domínio na API oficial.** Os dois eixos com "etc" são justamente os dois maiores, 89 e 102 operações. Entregar um recorte deles é entregar o recorte que o enunciado abriu explicitamente. Mapeamento operação a operação em `04-API-cobertura-por-dominio.md`.

O enunciado ainda convida: "Feel free to add any other screens or actions you frequently use". Isso está atendido dentro dos seis eixos, sem inventar destino novo: namespaces, ECP, licença, locks, sessões web, DocDB e servidores de linguagem externa entram sob Sistema operacional.

### 2.2 Requisitos gerais

- [ ] Aplicação totalmente funcional
- [ ] Não é import nem interface direta de biblioteca existente em outra linguagem
- [ ] Não é cópia de aplicação existente. Original em arquitetura e experiência
- [ ] Roda em IRIS Community Edition **ou** IRIS for Health Community Edition
- [ ] Código aberto, publicado no GitHub ou GitLab
- [ ] README em inglês, com passos de instalação
- [ ] Vídeo demo **ou** descrição detalhada de funcionamento
- [ ] Máximo de três submissões por desenvolvedor. Esta é uma; sobram duas
- [ ] Aprovada pela moderação do Open Exchange antes de aparecer na página do contest

### 2.3 Requisito que só existe no Open Exchange

⚠️ A página do Open Exchange exige que o README inclua **"a link to the idea"**. O anúncio na Developer Community não menciona isso.

Isso aponta para o Ideas Portal (`ideas.intersystems.com`). Duas ações:

1. Procurar no Ideas Portal uma ideia existente sobre portal de gestão alternativo ou sobre administração via API. Se existir, o README aponta para ela.
2. Se não existir, publicar a ideia do FlightDeck no Ideas Portal e apontar para ela. Custa minutos e fecha um requisito publicado.

Historicamente, implementar uma ideia do portal também costuma valer bônus de tecnologia.

---

## 3. Bônus de tecnologia: ainda não anunciados

A página do Open Exchange diz textualmente que os bônus de tecnologia ainda serão anunciados.

⚠️ **Isto é um item de acompanhamento diário, não uma curiosidade.** Em contests anteriores, os bônus decidem colocação entre aplicações tecnicamente próximas, porque somam pontos diretamente à nota dos experts. Eles são publicados depois do início, e quem só descobre na última semana perde os que exigiriam decisão arquitetural.

**Ação:** verificar diariamente o post de bônus na Developer Community e o canal do contest no Discord. Ao sair, reavaliar o cronograma no mesmo dia.

**Hedge barato, baseado no que costuma aparecer.** Nenhum destes é confirmado para este contest, e todos são baratos o suficiente para valerem a pena de qualquer forma:

| Item | Custo | Já previsto no projeto |
|---|---|---|
| Pacote IPM publicado | Baixo | Sim, UC11 |
| Docker Compose funcional | Baixo | Sim, UC11 |
| Demonstração online acessível | Médio | Não. Avaliar quando os bônus saírem |
| Artigo na Developer Community | Meio dia | Sim, na janela de votação |
| Vídeo no YouTube | Meio dia | Sim, dia 13 |
| Implementar ideia do Ideas Portal | Baixo | Ver Seção 2.3 |
| Uso de LLM ou IA | Variável | Não previsto. Não forçar: acoplamento artificial prejudica Applicability |

Sobre o último item, uma advertência. Se houver bônus para IA, a tentação será enfiar um assistente no portal. Um recurso que existe para pontuar e não para servir prejudica dois dos cinco critérios de julgamento. Se for feito, precisa ter função real: por exemplo, explicar em linguagem natural o efeito de uma mudança de permissão antes de aplicar, que é uma extensão legítima da análise de impacto.

---

## 4. Nomeações e onde estão as chances reais

| Nomeação | Prêmios | Situação |
|---|---|---|
| Experts | 5.000, 2.500, 1.000, 500, 300, e 100 do 6º ao 10º | **Alvo principal** |
| Community | 600, 400, 100 | Alvo secundário, decidido por voto |
| Freshmen | 600, 400, 100 | ❌ **Inelegível** |

**Sobre a inelegibilidade em Freshmen.** São dois critérios cumulativos: no máximo cinco contests anteriores **e** nunca ter ficado em 1º, 2º ou 3º em Experts ou Community. O 3º lugar compartilhado em Experts no contest #46 elimina a faixa. Não há o que fazer, e é melhor saber agora do que planejar em cima dela.

**Leitura prática da premiação.** A faixa de 6º ao 10º paga 100 dólares, então a diferença entre entregar bem e entregar muito bem é grande: 5.000 contra 100. Isso muda a postura. Não existe estratégia de "garantir um lugar": vale ir atrás dos três primeiros, e o caminho para isso são Complexity e Usability, os dois critérios onde uma submissão bem desenhada se separa do resto.

**Sobre a nomeação Community.** É decidida por voto, e voto se ganha com demonstração, não com arquitetura. O cluster de instrumentos e o dry-run existem exatamente para isso. Um artigo na Developer Community durante a votação tem efeito real e custa meio dia.

---

## 5. Onde a concorrência vai ser forte e onde vai ser fraca

A API oficial nivela a cobertura por baixo. Todo mundo tem os mesmos 273 endpoints. Isso permite prever com razoável confiança onde estarão as submissões:

**Onde quase todos vão entregar bem:** web apps, permissões, tarefas, processos. São mapeamento direto sobre a API, e uma tarde de trabalho cada.

**Onde muitos vão entregar pouco:**

- **Logs.** A API oficial não tem endpoint de log. Só auditoria e journal. `messages.log`, alertas e o log de interoperabilidade exigem trabalho próprio. É o único dos seis eixos obrigatórios onde ninguém ganha nada de graça, e portanto onde a maioria vai entregar o mínimo. **É a maior oportunidade de diferenciação da submissão.**
- **Os dois domínios com "etc".** Segurança tem 89 operações e Sistema tem 102. A tentação natural é cobrir o óbvio e parar. Cobertura integral aí é um argumento direto de Complexity.
- **Experiência.** Expor 273 endpoints em formulários gerados produz um cliente de API, não um portal. Paleta, grafo de entidades, dry-run com impacto e modo seguro são o que separa as duas coisas, e são caros de copiar.

**Onde a nossa submissão é vulnerável:**

- Prazo de treze dias para 273 operações mais provedores nativos de log, em solo.
- Autenticação sem armazenar credencial em instância anterior a 2026.2, que é um problema não resolvido e está no caminho crítico.
- Ambição de design compete com ambição de cobertura. A resposta é a concha convencional com dois momentos assinatura, já decidida.

---

## 6. Datas e obrigações processuais

| Data | Obrigação |
|---|---|
| 14/09/2026, 00:00 EST | Contest começa. Registro de aplicações abre |
| Contínuo | Acompanhar o anúncio dos bônus de tecnologia |
| **26/09/2026** | **Meta interna de submissão**, um dia antes do prazo |
| 27/09/2026, 23:59 EST | Prazo final de submissão |
| 28/09 a 04/10/2026 | Votação. Melhorias continuam permitidas |
| Durante a votação | Publicar artigo na Developer Community |

**Como submeter:** entrar no Open Exchange, abrir a página da aplicação, conferir os requisitos e clicar em "Apply for Contest". A aplicação passa por revisão antes de aparecer na página do contest. Isso significa que submeter no último minuto arrisca não ser aprovado a tempo, e é a razão da meta interna em 26/09.

**Canal de dúvidas:** o canal do contest no Discord da InterSystems, e os comentários do anúncio. As respostas de moderação nos comentários têm valor normativo, como já se viu na confirmação de que os seis eixos são obrigatórios.

---

## 7. Checklist de conformidade, para o dia 13

Cada linha é fechada com o ponteiro para a evidência, ou marcada como **ação do autor** com o que
falta e o prazo. Não existe terceiro estado: um visto sem ponteiro não é uma linha fechada, é uma
alegação — e o checklist existe justamente para o último dia não ser gasto reconferindo alegações.

Escopo:

- [x] **Os seis eixos implementados, com operação real de leitura e mutação** — features 002 a 005.
  Evidência: projetos Playwright `webapps`, `rest`, `permissions`, `security`, `secrets`, `tasks`,
  `system`, `instruments`, `processes`, `logs`, mais `mutation` e `last-admin` para as escritas.
  148 testes na matriz completa, verdes nas três instalações
  (`verification/feature-005-signoff.md`).
- [x] **273 operações da API oficial atribuídas e implementadas, ou explicitamente degradadas com
  motivo** — `scripts/build/check-coverage.py`, no build: *268 operations across 6 shipped domains,
  11 declined*, **sem lista de lacunas toleradas**. As 11 recusadas estão em
  `FlightDeck.Capability.Policy` com motivo e caminho nativo. As 5 restantes das 273 são a seção 0
  (Sessão), implementada na feature 001 e fora dos seis eixos que o gate conta: 8 + 31 + 89 + 24 +
  102 + 14 = 268.
- [x] **Logs com no mínimo cinco origens sob esquema normalizado** — feature 005. Evidência: projeto
  `logs` (13 testes) e, na instalação limpa 2026.2, as cinco origens responderam: audit 40 eventos,
  messages 40, journal 10, alerts 1, interoperabilidade 0 nomeando o namespace que leu.

Julgamento:

- [ ] **README lido por alguém que não conhece o projeto, sem dúvidas remanescentes** — passagens de
  agente registradas em `verification/cold-read.md`. **Ação do autor:** a passagem humana final, por
  alguém que conhece IRIS e não conhece o FlightDeck, cronometrada. Prazo: antes da submissão.
- [x] **Instalação testada em ambiente limpo, nas duas imagens Community** — `verification/install-runs.md`,
  executando os comandos do próprio README, lendo versão e contagem de capacidades do portal e não
  da tag.
- [x] **Todas as telas com dados no primeiro acesso** — registrado em cada corrida de
  `verification/install-runs.md`, com a última tela conferida nomeada.
- [ ] **Vídeo abrindo pelo cluster de instrumentos e pelo dry-run, não por menu** — roteiro e driver
  prontos: `docs/demo-script.md` (nove planos, tempos mínimos declarados) e
  `frontend/e2e/demo.spec.ts`, que dirige o portal na ordem do roteiro **na velocidade real do
  portal**. **Ação do autor:** gravar e publicar. Prazo: antes da submissão.

Formal:

- [x] **Licença MIT com arquivo no repositório** — `LICENSE` na raiz, citada na última seção do
  README. Conferido pelo gate `check-readme` (elemento 10).
- [ ] **README em inglês, com passos de instalação e link para a ideia** — inglês e instalação
  fechados e conferidos por `scripts/build/check-readme.py` (dez elementos, na ordem exigida).
  **Ação do autor:** publicar a ideia no Ideas Portal e me passar a URL; a linha final já está
  escrita no README esperando o link, marcada com `<!-- idea-link-pending -->`, e o gate avisa
  enquanto o marcador existir. Prazo: antes da submissão.
- [ ] **Vídeo publicado** — mesma ação do autor da linha do vídeo acima.
- [ ] **Submetido e aprovado pela moderação** — **ação do autor**, no Open Exchange. A aprovação é
  anterior à aparição na página do contest, e é por isso que a meta interna é 26/09.
- [ ] **Bônus de tecnologia conferidos e endereçados** — **ação do autor**, dependente do anúncio dos
  bônus, que ainda não saiu (§3). O que já está no projeto e costuma contar: IPM, Docker,
  InterSystems API oficial, e a implementação de uma ideia do Ideas Portal.

### Bônus de tecnologia

Os bônus continuam não anunciados (§3). Estes são os itens que o projeto pode reivindicar quando
saírem, cada um com o estado real hoje. Um bônus só entra aqui se o projeto já o cumpre por uma razão
própria: forçar correspondência para pontuar prejudica Applicability, que é um dos cinco critérios.

- [x] **Docker** — `docker compose up -d` como caminho de instalação principal, imagem construída
  sobre `intersystemsdc/iris-community:2026.2-zpm`. Verificado limpo nas duas imagens Community
  (`verification/install-runs.md`, feature 006).
- [ ] **Pacote IPM/ZPM publicado** — o pacote **constrói e instala**, mas **não está publicado**.
  Verificado: `zpm "iris-flightdeck package"` gera `iris-flightdeck-0.1.0.tgz` (532 KB, com o bundle
  do frontend), e esse artefato instala numa instância limpa sem FlightDeck — duas web applications,
  o papel de runtime, `demo=0`, portal 200, 262/0/11/273 capacidades, vitals lendo. O nome
  `iris-flightdeck` está livre no registry (552 pacotes, nenhum `flight*`).
  **Ação do autor:** publicar exige conta de publicador em `pm.community.intersystems.com`, que não
  está neste ambiente. Ver "As ações do autor" abaixo.
- [ ] **Vídeo no YouTube** — roteiro e driver prontos (`docs/demo-script.md`,
  `frontend/e2e/demo.spec.ts`). **Ação do autor:** gravar e publicar.
- [x] **Embedded Python** — `FlightDeck.Native.HostMetrics`, o provedor de CPU e memória do host,
  é Embedded Python: ler `/proc/stat` e `/proc/meminfo` é acesso a arquivo e parsing de texto.
  Justificativa técnica no README ("Where FlightDeck uses Embedded Python, and why"); equivalência
  antes/depois e degradação registradas em `verification/README.md`. Matriz completa verde nas três
  versões depois da reescrita.
- [ ] **Artigo na Developer Community** — rascunho do primeiro em `docs/article-1.md`.
  **Ação do autor:** revisar e publicar.
- [ ] **Segundo artigo na Developer Community** — não rascunhado. Material sobra: o adaptador de
  dialeto v1, a camada de mutação com análise de impacto, ou o gate de cobertura sem lista de
  lacunas toleradas. **Ação do autor**, se os bônus premiarem o segundo artigo.
- [ ] **Bug reproduzível no Embedded Python** — **nenhum encontrado**. A reescrita exercitou o
  runtime nas três imagens e ele se comportou corretamente em tudo. O único achado da reescrita foi
  semântica documentada de ObjectScript (`QUIT` com argumento dentro de `TRY`), registrado em
  `verification/README.md` e explicitamente **não** reivindicável como bug do Embedded Python.

**Não aplicáveis, e por quê.** Reivindicar qualquer um destes exigiria inventar acoplamento:

- [ ] ~~**First Time Contribution**~~ — não é a primeira contribuição do autor.
- [ ] ~~**Vector Search**~~ — o portal não armazena nem indexa nada. Não há corpus para vetorizar;
  o stream de logs é explicitamente um leitor, não uma plataforma de logs (README).
- [ ] ~~**Online Demo**~~ — uma demo pública exporia um portal de administração com credenciais
  conhecidas na internet. O caminho de uma linha em Docker já dá ao avaliador uma instância própria
  em minutos, que é melhor e mais honesto do que uma instância compartilhada e neutralizada.
- [ ] ~~**Community Idea**~~ — **nenhuma ideia com status Community Opportunity corresponde ao escopo
  do FlightDeck.** Forçar correspondência com uma ideia adjacente para capturar o bônus prejudicaria
  Applicability, que vale mais do que o bônus. O README aponta para a ideia do próprio FlightDeck no
  Ideas Portal (requisito do Open Exchange, §2.3), que é coisa diferente deste bônus.

### As ações do autor, reunidas

| Ação | O que falta | Prazo |
|---|---|---|
| Link da ideia | Publicar no `ideas.intersystems.com` e passar a URL | Antes da submissão |
| Vídeo | Gravar seguindo `docs/demo-script.md` e publicar | Antes da submissão |
| Leitura fria humana | Um leitor que conhece IRIS e não conhece o FlightDeck, cronometrado | Antes da submissão |
| ~~URL de clone no README~~ | **Fechado em 18/09.** O repositório foi publicado em `https://github.com/kcedd34/iris-flightdeck` (privado por enquanto) e o README traz o `git clone` real e copiável. Quando o repositório virar público, nada muda; se mudar de dono ou de nome, a linha do README acompanha | — |
| Publicar o pacote no registry | Conta de publicador em `pm.community.intersystems.com`. Com ela: `zpm "repo -n registry -r -url https://pm.community.intersystems.com/ -user <usuário> -pass <senha>"` e depois `zpm "iris-flightdeck publish"`. **O nome publicado está decidido e não muda**: o módulo chama-se `iris-flightdeck`, a submissão no Open Exchange está publicada com esse nome, e o comando do avaliador é, em toda parte, `zpm "install iris-flightdeck"`. O nome do produto continua FlightDeck; `iris-flightdeck` é o identificador do pacote e do repositório | Antes da submissão |

Nenhuma delas bloqueia as demais linhas: todas as outras fecham sem elas. São de minutos cada, e
todas foram deixadas prontas para receber só o dado ou a credencial que falta.
