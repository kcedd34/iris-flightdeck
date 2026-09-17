# PRD — FlightDeck for InterSystems IRIS

**Versão:** 2.0. Documento consolidado e autossuficiente. Substitui integralmente as versões 1.x e todos os adendos anteriores.
**Contest:** InterSystems Programming Contest #48, Build Your Own Management Portal
**Repositório:** `iris-flightdeck`, licença MIT
**Autor:** Carlos Eduardo Dias Duarte (Kadu). Submissão individual.
**Documentos irmãos:** `01-CONTEST-estrategia-e-conformidade.md`, `03-DESIGN.md`, `04-API-cobertura-por-dominio.md`, `05-GUIA-spec-kit.md`, `prototype.html`, `sysadmin-api-v2.json`

---

## 1. Resumo executivo

A InterSystems publicou, junto com o contest, uma especificação oficial de API de administração: `/api/admin`, OpenAPI 3.0.0, 190 caminhos e 273 operações. Isso define o campo de jogo de um modo específico: **cobertura não é diferencial**, porque todo concorrente tem os mesmos endpoints. Quem apenas gerar formulários sobre eles entrega um cliente de API, não um portal.

O FlightDeck é um portal de gestão alternativo para IRIS que cobre integralmente os seis eixos exigidos, incluindo a leitura estrita do "etc" do enunciado como cobertura total dos domínios de Segurança (89 operações) e Sistema (102 operações), e se diferencia por quatro decisões de produto:

1. **Navegação por comando, não por árvore.** Uma paleta (`Ctrl/Cmd+K`) é o ponto de entrada primário. O administrador digita o que quer e chega em um passo, sem conhecer a hierarquia.
2. **Entidades conectadas, não páginas isoladas.** Aplicação web, API, recurso, papel, usuário, tarefa, processo e evento de log formam um grafo navegável, com análise de impacto antes de mudanças de segurança.
3. **Segurança operacional embutida.** A sessão nasce somente leitura, toda mutação passa por pré-visualização de diferenças, e o portal mantém trilha da própria sessão.
4. **Logs de verdade.** A API oficial **não tem endpoints de log**: cobre auditoria e journal, e nada mais. `messages.log`, alertas e o log de eventos de interoperabilidade são provedores nativos que implementamos. Este é o único eixo obrigatório sem cobertura oficial e, portanto, o principal vetor de diferenciação.

A metáfora de projeto é a cabine de voo, e ela é estrutural, não decorativa: instrumentos (telemetria), checklists (tarefas), alarmes (logs), plano de voo (paleta) e copiloto (dry-run e confirmação). A gramática de cor do produto é herdada literalmente da convenção de glass cockpit, incluindo a distinção entre valor atual e valor comandado, que é exatamente a semântica do dry-run.

**Os cinco critérios de julgamento publicados** (Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability) governam o plano de entrega tanto quanto os requisitos funcionais. Dois deles são README e instalação.

---

## 2. Glossário

| Termo | Definição |
|---|---|
| RF, RNF, UC, RN | Requisito funcional, não funcional, caso de uso, regra de negócio (módulo `RN-FD`) |
| IRIS CE / IRIS4H CE | `intersystemsdc/iris-community:latest` e `intersystemsdc/irishealth-community:latest` |
| SysAdmin API | A API oficial do contest, base `/api/admin`, 273 operações, especificada em `sysadmin-api-v2.json` |
| Provedor nativo | Código ObjectScript próprio que entrega o que a SysAdmin API não cobre. Hoje: logs e CPU/memória do host (constitution v2.0.0) |
| IPM / ZPM | InterSystems Package Manager, distribuição via `module.xml` |
| Entidade | Qualquer objeto administrável exposto pelo portal |
| Grafo de entidades | Modelo de navegação em que toda entidade expõe seus vínculos, permitindo salto entre domínios |
| Paleta de comandos | Campo de busca e execução invocado por `Ctrl/Cmd+K`, ponto de entrada primário |
| Modo seguro | Estado inicial de toda sessão, somente leitura. Desarme explícito, por aba |
| Dry-run | Pré-visualização das diferenças de uma mutação, antes da confirmação, sem efeito no servidor |
| Trilha de sessão | Registro local das ações da sessão, exportável em JSON. Não substitui a auditoria do IRIS |
| Privilégio efetivo | Composição usuário mais papéis mais papéis herdados, sempre exibida com a procedência |
| Análise de impacto | Quais usuários e objetos perdem acesso se um papel, recurso ou privilégio for alterado |
| Instrumento | Componente de telemetria contínua, com janela deslizante, renderizado em canvas |
| Degradação graciosa | Recurso indisponível na versão ou edição aparece desabilitado com motivo, sem quebrar tela |
| Resultado assíncrono | Padrão da SysAdmin API em que o dado chega por tarefa, consultada em `/v2/async-result` |

---

## 3. Contexto

### 3.1 Problema

O Management Portal nativo é completo e organizado como árvore profunda de páginas herdadas de décadas de evolução. Três atritos recorrentes:

- **Navegação.** Encontrar uma tela depende de saber onde ela mora. Não há busca global por objeto administrável.
- **Correlação.** As telas são silos. Um recurso não mostra quem o consome, um erro de log não leva ao processo que o gerou. A correlação acontece na cabeça do administrador.
- **Confiança.** Mutações são aplicadas sem pré-visualização do efeito e sem análise de impacto. Administrar segurança em produção exige cautela que a ferramenta não apoia.

### 3.2 Contexto do contest

Detalhamento completo em `01-CONTEST-estrategia-e-conformidade.md`. O essencial para o desenho:

- Seis eixos obrigatórios, confirmados como não negociáveis pela moderação nos comentários do anúncio.
- Critérios de julgamento: Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability.
- Prazo: submissão em 27/09/2026, meta interna em 26/09. Votação até 04/10.
- Bônus de tecnologia ainda não anunciados, acompanhamento diário obrigatório.
- Freshmen Nomination inelegível. Alvo: Experts, com Community como secundário.

### 3.3 Contexto técnico

- A SysAdmin API cobre cinco dos seis eixos. O trabalho é de composição e experiência, não de engenharia reversa de classes.
- Cada operação declara o privilégio exigido no próprio resumo (`%Admin_Operate:U`, `%Admin_Manage:U`, `%Admin_Secure:U`). O mapa de capacidades da sessão é **derivado da especificação**, não codificado à mão.
- O explorador de APIs REST do UC04 não é coberto pela SysAdmin API e continua sobre `/api/mgmnt/` e `%REST.API`.
- ⚠️ Os endpoints `/login`, `/logout`, `/refresh` e `/revoke` estão marcados como disponíveis apenas a partir do IRIS 2026.2. As imagens Community provavelmente não são. Ver risco 1.
- ⚠️ Os schemas `SystemResourcesStats` e `SharedMemoryUsage` vêm com `properties` vazio. A forma da resposta precisa ser descoberta contra a instância.
- ⚠️ Espaço livre em disco chega por tarefa assíncrona (`AsyncTaskResultDatabaseMetrics`, com `DiskFree`, `AvailableSpace`, `Full`), consultada em `/v2/async-result`.
- O schema `Process` traz `CanBeTerminated`, `CanBeSuspended` e `CanReceiveBroadcast`. Esses campos governam diretamente o estado habilitado dos botões: a API já respondeu, e a interface não adivinha.
- Ambiente de desenvolvimento integralmente em WSL2, com Docker Engine nativo, sem Docker Desktop.

---

## 4. Objetivos

- Cobrir integralmente os seis eixos, com as 273 operações da SysAdmin API atribuídas e implementadas, ou explicitamente degradadas com motivo.
- Entregar o domínio de logs com profundidade real, por ser o único eixo sem cobertura oficial e o principal diferencial competitivo.
- Reduzir o caminho até qualquer tarefa administrativa a um passo de teclado.
- Tornar visíveis as relações entre entidades, incluindo análise de impacto antes de mudanças de segurança.
- Tornar toda mutação reversível em intenção: modo seguro por padrão, diferenças pré-visualizadas, confirmação graduada e trilha exportável.
- Atender os cinco critérios de julgamento de forma deliberada, tratando README e instalação como entregáveis de primeira classe.
- Instalação em um comando, sem configuração posterior, verificada nas duas imagens Community.

---

## 5. Stakeholders

| Stakeholder | Papel |
|---|---|
| Júri de experts | Avalia pelos cinco critérios publicados. Público primário |
| Comunidade (votação) | Avalia por demonstração, README e vídeo. Público primário dos requisitos de design |
| Administrador IRIS | Usuário final. Opera segurança, tarefas, telemetria e logs |
| Desenvolvedor IRIS | Usuário secundário. Usa o explorador de APIs e a gestão de aplicações web |
| Moderação do Open Exchange | Aprova a submissão. Exige README em inglês, link para a ideia, instalação reproduzível e licença aberta |
| Autor (Kadu) | Product Owner e desenvolvedor único. Decide escopo, prioridade e cortes |

---

## 6. Requisitos Funcionais

- **RF01 — Sessão, identidade e modo seguro.** Autenticar contra o IRIS, executar toda operação sob a identidade e os papéis do usuário, derivar o mapa de capacidades da especificação da API, iniciar toda sessão em modo somente leitura. *(UC01; RN-FD-01 a RN-FD-04)*
- **RF02 — Navegação por paleta de comandos.** Paleta invocável por atalho, capaz de localizar entidades e executar ações, com resultados agrupados por domínio e navegação por teclado. *(UC02; RN-FD-05, RN-FD-06)*
- **RF03 — Gestão de aplicações web.** Cobertura integral de `/v2/web-app` e `/v2/web-app/pct-access`, com sinalização de exposição sem autenticação e vínculos no grafo. *(UC03; RN-FD-07, RN-FD-12, RN-FD-13)*
- **RF04 — Exploração e teste de APIs REST.** Descobrir serviços REST, exibir especificação OpenAPI, executar requisições de teste confinadas à própria instância. *(UC04; RN-FD-08, RN-FD-09)*
- **RF05 — Gestão de permissões.** Cobertura integral das 31 operações de usuários, papéis, recursos, serviços, privilégios SQL e rotinas privilegiadas, com privilégio efetivo, grafo e análise de impacto. *(UC05; RN-FD-10 a RN-FD-13)*
- **RF06 — Gestão de segurança e segredos.** Cobertura integral das 89 operações: TLS, X.509, OAuth 2.0 nos três papéis, wallet, criptografia, LDAP, MFT, configuração de auditoria, superserver. Material secreto nunca exibido. *(UC06; RN-FD-14 a RN-FD-16)*
- **RF07 — Gestão de tarefas.** Cobertura integral das 24 operações: tarefas, histórico, próximas execuções, gerenciador, categorias do Work Queue Manager e resultados assíncronos. *(UC07; RN-FD-17, RN-FD-18, RN-FD-32)*
- **RF08 — Gestão de sistema operacional.** Cobertura integral das 102 operações: processos, monitor, bancos, diretórios de banco, namespaces, dispositivos, licença, locks, sessões web, ECP, servidores de linguagem externa, DocDB e finalidades de acesso a arquivo. Telemetria contínua em canvas. *(UC08; RN-FD-19 a RN-FD-22, RN-FD-32)*
- **RF09 — Fluxo unificado de logs.** Cinco origens sob esquema normalizado: auditoria e journal pela API oficial; `messages.log`, alertas e log de interoperabilidade por provedores nativos. Filtro, acompanhamento ao vivo, registro original preservado e correlação para entidade. *(UC09; RN-FD-23 a RN-FD-26)*
- **RF10 — Mutação segura.** Diferenças exibidas antes de aplicar, confirmação graduada, trilha de sessão, concorrência otimista. *(UC10; RN-FD-03, RN-FD-04, RN-FD-27, RN-FD-31)*
- **RF11 — Instalação e provisionamento.** Um comando via Docker Compose, instalação alternativa por IPM, dados de demonstração no primeiro acesso. *(UC11; RN-FD-28, RN-FD-29)*
- **RF12 — Auto-documentação.** A API do FlightDeck é descoberta e exibida pelo próprio explorador do FlightDeck. *(UC04; RN-FD-09)*

---

## 7. Casos de Uso

> Cada UC declara as regras `RN-FD` que aplica e as operações da SysAdmin API que consome. O mapeamento operação a operação está em `04-API-cobertura-por-dominio.md`.

---

### UC01 — Autenticar e estabelecer sessão

**Ator:** Administrador de sistemas IRIS
**Consome:** `GET /info`, e o caminho de autenticação decidido pelo risco 1

**História:** Como administrador, quero entrar com minha própria credencial do IRIS e saber exatamente o que posso fazer, para operar sem risco de agir fora do meu nível de permissão.

**Pré-condições:** instância no ar, aplicação web instalada, usuário com credencial válida.

**Contexto adicional:**
O portal não tem base de usuários própria e não armazena senha. `GET /info` devolve versão, edição e privilégios do usuário, e é a sonda que alimenta tanto a identificação da instância quanto o mapa de capacidades.

O mapa de capacidades é **derivado da especificação da API**: cada operação declara seu privilégio exigido, e cruzar isso com os privilégios do usuário produz, sem código manual, a lista do que habilitar. Tabela codificada à mão diverge da plataforma; tabela derivada não pode divergir.

Ações fora do alcance do usuário aparecem **desabilitadas com o motivo**, nunca ocultas. Ocultar ensina que a funcionalidade não existe; desabilitar com motivo ensina qual permissão pedir.

**Fluxo Principal:**
1. Usuário acessa a URL do portal.
2. Sistema apresenta a entrada, identificando instância, versão e edição detectadas via `GET /info`.
3. Usuário informa credencial do IRIS.
4. Sistema autentica pelo caminho disponível na instância (RN-FD-01).
5. Sistema deriva o mapa de capacidades da sessão a partir dos privilégios e da especificação (RN-FD-02).
6. Sistema abre o painel inicial em modo seguro, com indicador persistente (RN-FD-03).
7. Para mutar, o usuário desarma o modo seguro explicitamente, e o indicador muda de forma inequívoca.

**Fluxos Alternativos:**
- **A1** (4): credencial inválida. Erro genérico, sem distinguir usuário inexistente de senha incorreta.
- **A2** (5): usuário sem privilégio administrativo. Leitura restrita, informando quais recursos faltam.
- **A3** (4): instância anterior a 2026.2, sem os endpoints JWT. O sistema usa o caminho de fallback determinado na verificação do dia 1, e **em nenhuma hipótese armazena credencial** (RN-FD-01).
- **A4** (qualquer): sessão expirada. Sobreposição de reautenticação sem navegar para fora; entrada digitada preservada, estado calculado descartado e recomputado (RN-FD-31).
- **A5** (qualquer): aba fechada com modo seguro desarmado. A próxima sessão nasce em modo seguro, sem exceção.

**Regras:** RN-FD-01, RN-FD-02, RN-FD-03, RN-FD-04, RN-FD-31, RN-FD-33.

```gherkin
1. Dado que o usuário autentica com sucesso
   Quando o painel inicial é aberto
   Então a sessão deve estar em modo seguro
   E o indicador de somente leitura deve estar visível de forma persistente

2. Dado que o usuário não possui o privilégio exigido por uma operação da API
   Quando a tela correspondente é renderizada
   Então a ação deve aparecer desabilitada
   E o recurso e a permissão exigidos devem ser informados

3. Dado que a instância não possui os endpoints de autenticação JWT
   Quando o usuário autentica
   Então o acesso deve funcionar pelo caminho de fallback
   E nenhuma credencial deve ser persistida em qualquer camada

4. Dado que a sessão expirou com uma edição não salva aberta
   Quando o usuário reautentica
   Então a mesma tela deve ser restaurada
   E a entrada digitada preservada
   E qualquer diferença calculada deve ser recomputada antes de permitir confirmação
```

---

### UC02 — Navegar e agir pela paleta de comandos

**Ator:** Administrador
**Consome:** índice local de ações, busca de entidades no backend

**História:** Como administrador, quero encontrar qualquer objeto ou executar qualquer ação digitando seu nome, para não precisar memorizar a hierarquia de menus.

**Contexto adicional:**
Com 273 operações e seis domínios com seções internas, a paleta deixa de ser conveniência e passa a ser a forma viável de navegação. A árvore equivalente teria profundidade comparável à do portal nativo, que é o problema que o produto existe para resolver.

Indexa duas categorias: entidades (busca no servidor, com debounce) e ações (resolução local). A paleta respeita o modo seguro: ações de mutação aparecem marcadas como bloqueadas, com o desarme oferecido como passo encadeado.

**Fluxo Principal:**
1. Usuário aciona `Ctrl+K` ou `Cmd+K` em qualquer tela.
2. Sistema abre a paleta com foco no campo e exibe ações recentes.
3. Usuário digita um termo.
4. Sistema busca em paralelo nas ações locais e nas entidades, e agrupa por domínio (RN-FD-05).
5. Usuário navega com setas e confirma com Enter.
6. Sistema navega ou executa, e registra o uso para a lista de recentes.

**Fluxos Alternativos:**
- **A1** (4): nenhum resultado. Sugere os domínios pesquisáveis e a documentação de atalhos.
- **A2** (5): ação de mutação com modo seguro armado. Oferece o desarme como passo anterior (RN-FD-03).
- **A3** (4): busca de entidades indisponível. A paleta segue funcional com ações locais, sinalizando a parte indisponível (RN-FD-06).
- **A4** (4): resultados acima do limite. Exibe o topo do ranking, indica o total e oferece refinamento por domínio.

**Regras:** RN-FD-03, RN-FD-05, RN-FD-06.

```gherkin
1. Dado que o usuário está em qualquer tela
   Quando pressiona Ctrl+K ou Cmd+K
   Então a paleta deve abrir com o foco no campo de busca

2. Dado que o termo corresponde a entidades de domínios diferentes
   Quando os resultados são exibidos
   Então devem estar agrupados por domínio
   E cada resultado deve exibir o contexto que o desambigua

3. Dado que a busca de entidades está indisponível
   Quando o usuário digita um termo
   Então as ações locais devem continuar sendo oferecidas
   E a indisponibilidade deve ser sinalizada

4. Dado que o modo seguro está armado
   Quando o usuário seleciona uma ação de mutação
   Então o sistema deve oferecer o desarme antes de executar
```

---

### UC03 — Gerenciar aplicações web

**Ator:** Administrador
**Consome:** `/v2/web-app`, `/v2/web-apps`, `/v2/web-app/pct-access`, `/v2/web-app/pct-accesses` (8 operações, cobertura integral)

**História:** Como administrador, quero ver e ajustar as aplicações web com seu contexto de segurança visível, para entender o que está exposto e sob qual proteção.

**Contexto adicional:**
A listagem responde, em uma leitura, a três perguntas: o que está habilitado, o que está exposto sem autenticação, e o que é REST. Aplicações sem autenticação recebem destaque de atenção, porque é a configuração que mais gera incidente real.

Cada aplicação expõe seus vínculos: recurso que a protege, papéis que concedem esse recurso, usuários com esses papéis, e, quando REST, a especificação no explorador (UC04).

**Fluxo Principal:**
1. Usuário acessa o domínio pela paleta ou pelo rail.
2. Sistema lista com namespace, estado, recurso, métodos de autenticação e classe de despacho (RN-FD-07).
3. Usuário filtra por namespace, estado, tipo ou ausência de autenticação.
4. Usuário abre uma aplicação e inspeciona detalhe e vínculos (RN-FD-13).
5. Usuário edita atributos permitidos, incluindo acessos por porcentagem.
6. Sistema exibe o dry-run das diferenças (RN-FD-27).
7. Usuário confirma; o sistema aplica e registra na trilha.

**Fluxos Alternativos:**
- **A1** (5): modo seguro armado. Campos em leitura, com convite ao desarme.
- **A2** (7): a API rejeita. Mensagem original exibida, formulário preenchido mantido (RN-FD-12).
- **A3** (4): aplicação de sistema. Natureza sinalizada, operações destrutivas restritas.
- **A4** (5): tentativa de desabilitar a aplicação que serve o próprio portal. Bloqueio com explicação de autoproteção.

**Regras:** RN-FD-03, RN-FD-07, RN-FD-12, RN-FD-13, RN-FD-27.

```gherkin
1. Dado que existe uma aplicação web acessível sem autenticação
   Quando a listagem é exibida
   Então essa aplicação deve receber destaque visual de atenção

2. Dado que o usuário abre uma aplicação protegida por um recurso
   Quando o detalhe é exibido
   Então devem estar acessíveis, em um clique, os papéis que concedem esse recurso

3. Dado que o usuário edita uma aplicação com o modo seguro desarmado
   Quando confirma a edição
   Então as diferenças devem ser exibidas antes de aplicar
   E a ação registrada na trilha após aplicar

4. Dado que o usuário tenta desabilitar a aplicação que serve o portal
   Quando confirma a ação
   Então o sistema deve bloquear a operação e explicar o motivo
```

---

### UC04 — Explorar e testar APIs REST

**Ator:** Desenvolvedor IRIS
**Consome:** `/api/mgmnt/` e `%REST.API`. **Não coberto pela SysAdmin API**

**História:** Como desenvolvedor, quero descobrir as APIs REST da instância, ler sua especificação e testá-las sem sair do portal.

**Contexto adicional:**
Compõe duas capacidades nativas: descoberta de serviços REST e obtenção da especificação OpenAPI. Serviços definidos por especificação e serviços codificados manualmente têm caminhos de descoberta distintos, e o portal cobre ambos, sinalizando quando não há especificação.

O executor de requisições é confinado por construção: o destino deriva sempre da instância corrente, nunca de host informado pelo usuário. O portal não é proxy de requisições externas (RN-FD-08). Esse ponto precisa estar explícito no README, porque o júri provavelmente vai olhá-lo.

O FlightDeck expõe a própria API sob especificação e aparece na própria lista (RF12).

**Fluxo Principal:**
1. Usuário acessa o explorador.
2. Sistema lista os serviços descobertos, por namespace, indicando quais têm especificação (RN-FD-09).
3. Usuário seleciona um serviço.
4. Sistema renderiza a especificação, agrupada por caminho e método, com esquemas.
5. Usuário seleciona uma operação, preenche parâmetros e corpo, e executa.
6. Sistema executa contra a própria instância, no contexto do usuário autenticado (RN-FD-08).
7. Sistema exibe status, tempo, cabeçalhos e corpo formatado, e oferece cópia como `curl`.

**Fluxos Alternativos:**
- **A1** (4): serviço sem especificação. Exibe metadados e permite requisição livre por caminho.
- **A2** (6): erro. Resposta apresentada integralmente, sem interpretação.
- **A3** (6): método de mutação com modo seguro armado. Execução bloqueada, desarme oferecido.
- **A4** (2): nenhum serviço no namespace. Estado vazio com explicação e ponteiro para o namespace do portal.

**Regras:** RN-FD-03, RN-FD-08, RN-FD-09.

```gherkin
1. Dado que a instância possui serviços REST com e sem especificação
   Quando a lista é exibida
   Então ambos devem aparecer
   E os sem especificação devem estar sinalizados

2. Dado que o usuário executa uma requisição de teste
   Quando a resposta retorna
   Então devem ser exibidos status, tempo, cabeçalhos e corpo formatado
   E deve ser possível copiar a requisição equivalente em curl

3. Dado que o modo seguro está armado
   Quando o usuário tenta executar POST, PUT, PATCH ou DELETE
   Então a execução deve ser bloqueada e o desarme oferecido

4. Dado que o FlightDeck está instalado
   Quando o usuário lista os serviços descobertos
   Então a API do próprio FlightDeck deve aparecer com sua especificação
```

---

### UC05 — Gerenciar permissões e analisar impacto

**Ator:** Administrador
**Consome:** 31 operações de `/v2/security`: `user`, `users`, `role`, `roles`, `role/owners`, `resource`, `resources`, `service`, `services`, `sql-privileges`, `sql-admin-privileges`, `sql-column-privileges`, `privileged-routine`, `privileged-routines` (cobertura integral)

**História:** Como administrador, quero enxergar o caminho completo entre um usuário e um recurso, e saber o que quebra antes de mudar algo.

**Contexto adicional:**
Domínio de maior valor percebido e principal argumento de Complexity. O portal nativo mostra as peças; o FlightDeck mostra a **cadeia**: usuário para papéis, papéis para papéis herdados, papéis para privilégios, privilégios para recursos, recursos para os objetos que protegem.

Duas capacidades derivam dela:

- **Privilégio efetivo:** o conjunto resultante, sempre com a origem de cada permissão, nunca só o resultado (RN-FD-10).
- **Análise de impacto:** dada uma remoção pretendida, quais usuários e objetos perdem acesso. Roda antes da confirmação, como parte do dry-run (RN-FD-11).

Privilégios SQL e rotinas privilegiadas entram no mesmo grafo, e são a parte que a maioria das submissões vai ignorar.

**Fluxo Principal:**
1. Usuário acessa o domínio, na seção de usuários, papéis, recursos, serviços, privilégios SQL ou rotinas privilegiadas.
2. Sistema lista as entidades da seção, com contagem de vínculos.
3. Usuário seleciona uma entidade e inspeciona o grafo (RN-FD-13).
4. Para um usuário, o sistema apresenta os privilégios efetivos com procedência (RN-FD-10).
5. Usuário propõe uma mudança.
6. Sistema executa a análise de impacto e a apresenta no dry-run (RN-FD-11, RN-FD-27).
7. Usuário confirma; o sistema aplica e registra na trilha.

**Fluxos Alternativos:**
- **A1** (6): a mudança removeria o último caminho de administração da instância. Bloqueio com explicação (RN-FD-12).
- **A2** (6): a mudança afeta o usuário da sessão. Confirmação reforçada, com aviso de efeito imediato.
- **A3** (4): papel concedido por mecanismo externo, delegação ou LDAP. Origem sinalizada, informando que o portal não a gerencia ali.
- **A4** (5): entidade de sistema. Visualização completa, edição desabilitada com motivo.

**Regras:** RN-FD-03, RN-FD-10 a RN-FD-13, RN-FD-27.

```gherkin
1. Dado que um usuário possui um privilégio por papel herdado
   Quando seus privilégios efetivos são exibidos
   Então o privilégio deve aparecer
   E a cadeia de papéis que o concede deve ser exibida junto

2. Dado que o administrador propõe remover um papel de um recurso
   Quando o dry-run é exibido
   Então devem ser listados os usuários que perdem acesso
   E os objetos protegidos que ficam inacessíveis

3. Dado que a mudança removeria o último acesso administrativo da instância
   Quando o administrador confirma
   Então a operação deve ser bloqueada e o motivo explicado

4. Dado que a mudança afeta o usuário da sessão atual
   Quando o dry-run é exibido
   Então deve ser exigida confirmação reforçada
   E advertido o efeito imediato na sessão
```

---

### UC06 — Gerenciar segurança e segredos

**Ator:** Administrador
**Consome:** 89 operações. `/v2/wallet` (7, integral) e `/v2/security` em TLS, X.509, OAuth 2.0 cliente, servidor e resource server, criptografia, LDAP, MFT, configuração de auditoria, superserver, delegated (cobertura integral do "etc" do enunciado)

**História:** Como administrador, quero administrar TLS, certificados, OAuth, segredos e criptografia em um lugar só, com validade e vínculos visíveis.

**Contexto adicional:**
O maior domínio da API e a leitura mais literal do "etc" do enunciado. Reúne famílias que a plataforma trata separadamente e que na operação são consumidas juntas.

O wallet entra no grafo naturalmente: uma coleção é protegida por um recurso, concedido por papéis, que pertencem a usuários. O portal explora esse encadeamento para responder "quem consegue usar este segredo", pergunta que hoje exige navegação manual.

**Princípio inegociável:** o portal **nunca exibe material secreto**, em tela, log ou resposta de API. Segredos, chaves privadas e client secrets são apenas definidos ou substituídos, nunca lidos de volta (RN-FD-14). É mais restritivo que o estritamente necessário, e assumido como postura de produto.

Itens com validade recebem tratamento temporal: dias restantes, faixas (válido, próximo do vencimento, vencido), críticos agregados no painel inicial (RN-FD-15).

**Fluxo Principal:**
1. Usuário acessa o domínio e escolhe a seção: TLS, X.509, OAuth, wallet, criptografia, LDAP, MFT, auditoria ou superserver.
2. Sistema lista os itens, com estado, validade quando aplicável e vínculos (RN-FD-15).
3. Usuário abre um item e inspeciona detalhe, vínculos e consumidores.
4. Usuário cria ou edita.
5. Sistema valida, exibe o dry-run e mascara integralmente campos secretos (RN-FD-14, RN-FD-27).
6. Usuário confirma; o sistema aplica e registra na trilha.
7. Para TLS, o usuário dispara teste de conexão e vê o resultado original (RN-FD-16).

**Fluxos Alternativos:**
- **A1** (1): seção indisponível na versão ou edição. Aparece desabilitada, com versão mínima informada (RN-FD-32).
- **A2** (5): tentativa de visualizar segredo gravado. A operação não é oferecida em nenhum caminho; apenas substituir e excluir.
- **A3** (2): certificado vencido ou vencendo na janela de alerta. Destacado na lista e agregado no painel inicial.
- **A4** (7): teste de conexão falha. Erro original exibido, item inalterado.
- **A5** (4): exclusão de coleção do wallet com segredos. Confirmação reforçada com a contagem de segredos afetados.

**Regras:** RN-FD-03, RN-FD-14, RN-FD-15, RN-FD-16, RN-FD-27, RN-FD-32.

```gherkin
1. Dado que existe um segredo gravado no wallet
   Quando o usuário abre o detalhe desse segredo
   Então o conteúdo não deve ser exibido em nenhuma forma
   E devem ser oferecidas apenas as operações de substituir e excluir

2. Dado que existe um certificado que vence dentro da janela de alerta
   Quando o usuário abre o painel inicial
   Então esse certificado deve aparecer entre os itens de atenção

3. Dado que uma seção do domínio não está disponível na instância
   Quando o usuário acessa o domínio
   Então essa seção deve aparecer desabilitada com o motivo
   E as demais devem funcionar normalmente

4. Dado que o usuário abre uma coleção do wallet protegida por um recurso
   Quando o detalhe é exibido
   Então deve ser possível ver, em um clique, quais usuários podem usar seus segredos
```

---

### UC07 — Gerenciar tarefas

**Ator:** Administrador
**Consome:** 24 operações. `/v2/task` (15, integral), `/v2/wqm-category` (4, integral), `/v2/async-result` (5, integral)

**História:** Como administrador, quero ver o que está agendado, o que falhou e por quê, e reexecutar sob demanda.

**Contexto adicional:**
A diferença de experiência está na linha do tempo. A listagem apresenta, por tarefa, a última execução, o resultado, a duração e a próxima execução, mais uma faixa compacta com o histórico recente, de modo que falha intermitente seja visível sem abrir o detalhe.

O erro de execução é conteúdo de primeira classe: o detalhe traz a mensagem completa e salta direto para os logs correlacionados do período (UC09).

O gerenciador de tarefas em si (`/v2/task/manager`) tem suspensão e retomada globais, que são operação destrutiva de grau reforçado: suspender o gerenciador para toda a instância.

Resultados assíncronos são listados aqui, e o mesmo componente serve o instrumento de disco do UC08 (RN-FD-32).

**Fluxo Principal:**
1. Usuário acessa o domínio, na seção de tarefas, categorias do Work Queue Manager ou resultados assíncronos.
2. Sistema lista com estado, última execução, resultado, duração, próxima execução e histórico recente (RN-FD-17).
3. Usuário filtra por estado, namespace ou resultado.
4. Usuário abre uma tarefa e inspeciona definição e histórico completo.
5. Usuário cria, edita, suspende, retoma ou exclui.
6. Sistema exibe o dry-run e aplica após confirmação (RN-FD-27).
7. Usuário dispara execução sob demanda; o sistema acompanha até a conclusão (RN-FD-18).

**Fluxos Alternativos:**
- **A1** (7): tarefa já em execução. Execução concorrente impedida, com o horário de início informado.
- **A2** (4): execução falhou. Mensagem completa e salto para os logs do período (RN-FD-26).
- **A3** (5): tarefa de sistema. Inspeção e suspensão permitidas, exclusão desabilitada com motivo.
- **A4** (7): execução não conclui no tempo de acompanhamento. Sinaliza andamento e segue por polling, sem travar a interface.
- **A5** (5): suspensão do gerenciador inteiro. Confirmação reforçada, explicando o efeito sobre toda a instância.

**Regras:** RN-FD-03, RN-FD-17, RN-FD-18, RN-FD-26, RN-FD-27, RN-FD-32.

```gherkin
1. Dado que uma tarefa possui histórico de execuções
   Quando a listagem é exibida
   Então a faixa de histórico recente deve estar visível sem abrir o detalhe

2. Dado que a última execução falhou
   Quando o usuário abre o detalhe da execução
   Então a mensagem de erro completa deve ser exibida
   E deve haver salto direto para os logs do período

3. Dado que uma tarefa está em execução
   Quando o usuário tenta dispará-la sob demanda
   Então a execução concorrente deve ser impedida com o início informado

4. Dado que o usuário suspende o gerenciador de tarefas
   Quando a confirmação é exibida
   Então deve ser exigida confirmação reforçada
   E explicado o efeito sobre toda a instância
```

---

### UC08 — Gerenciar sistema operacional

**Ator:** Administrador
**Consome:** 102 operações, cobertura integral. `/v2/process` (6), `/v2/monitor` (7), `/v2/database` (4), `/v2/database-dir` (15), `/v2/namespace` (18), `/v2/device` (10), `/v2/license` (7), `/v2/lock` (2), `/v2/web-session` (2), `/v2/ecp` (13), `/v2/ext-lang-server` (7), `/v2/doc-db` (4), `/v2/fs-access-purpose` (7)

**História:** Como administrador, quero ver CPU, memória, disco, processos e o resto do estado da instância em uma tela viva.

**Contexto adicional:**
Maior domínio em número de operações e o que carrega a metáfora de cabine. É também a leitura integral do segundo "etc" do enunciado.

O topo é o painel de instrumentos: séries temporais curtas, atualizadas continuamente, com janela deslizante mantida no cliente. O portal **não persiste histórico de métricas** (RN-FD-21): retenção compete com ferramenta de observabilidade e está fora do objetivo.

⚠️ **Espaço livre em disco é assíncrono.** Chega por tarefa consultada em `/v2/async-result`. O instrumento de disco usa o padrão dispara e consulta, mantendo o último valor conhecido enquanto uma atualização está em voo. Nunca apaga o número, nunca troca o número por indicador de carregamento (RN-FD-32).

⚠️ **`SystemResourcesStats` e `SharedMemoryUsage` não declaram forma na especificação.** Devem ser sondados contra a instância antes de serem tipados.

A lista de processos é a parte operacional: filtro, ordenação por consumo, inspeção e encerramento. **Os campos `CanBeTerminated`, `CanBeSuspended` e `CanReceiveBroadcast` do próprio schema governam o estado dos botões.** A API já respondeu o que é permitido; a interface não adivinha (RN-FD-34).

Seções: instrumentos, processos, bancos e diretórios, namespaces, dispositivos, licença, locks, sessões web, ECP, servidores de linguagem externa, DocDB, finalidades de acesso a arquivo.

**Fluxo Principal:**
1. Usuário acessa o domínio; a seção inicial é a de instrumentos.
2. Sistema estabelece a telemetria e renderiza CPU, memória, disco e atividade (RN-FD-19).
3. Sistema apresenta uso de disco por banco, com espaço livre e limite de crescimento, pelo padrão assíncrono.
4. Usuário abre processos, filtra e ordena por consumo.
5. Usuário inspecciona um processo: namespace, usuário, rotina, estado, consumo, tempo ativo, papéis de login e escalados.
6. Usuário encerra, suspende ou envia broadcast, conforme os campos de capacidade do processo (RN-FD-34).
7. Encerramento exige confirmação com digitação do identificador (RN-FD-22).
8. Sistema aplica, registra na trilha e atualiza a lista.
9. Usuário navega pelas demais seções.

**Fluxos Alternativos:**
- **A1** (2): SSE indisponível. Queda automática para polling, com o modo sinalizado (RN-FD-20).
- **A2** (qualquer): aba perde o foco. Telemetria pausada e retomada ao recuperar o foco, preservando a janela acumulada.
- **A3** (6): processo alvo é o da própria sessão. Encerramento bloqueado com explicação (RN-FD-12).
- **A4** (3): banco acima do limiar de ocupação. Destacado e agregado no painel inicial.
- **A5** (2): métrica indisponível na edição. Instrumento desabilitado com motivo, demais ativos (RN-FD-32).
- **A6** (6): a API indica que o processo não pode ser encerrado. O botão aparece desabilitado com o motivo, e a ação nunca é tentada.

**Regras:** RN-FD-03, RN-FD-12, RN-FD-19 a RN-FD-22, RN-FD-32, RN-FD-34.

```gherkin
1. Dado que o painel de instrumentos está aberto
   Quando o tempo passa
   Então os instrumentos devem se atualizar continuamente
   E manter uma janela deslizante de histórico recente

2. Dado que a métrica de espaço em disco chega por tarefa assíncrona
   Quando uma atualização está em andamento
   Então o último valor conhecido deve permanecer visível
   E nunca ser substituído por um indicador de carregamento

3. Dado que a API informa que um processo não pode ser encerrado
   Quando a lista é exibida
   Então o botão de encerrar deve aparecer desabilitado com o motivo

4. Dado que o usuário solicita o encerramento de um processo permitido
   Quando a confirmação é exibida
   Então deve ser exigida a digitação do identificador do processo
```

---

### UC09 — Explorar o fluxo unificado de logs

**Ator:** Administrador
**Consome:** `/v2/security/audit/events`, `/audit/record`, `/audit/enabled` e `/v2/journal` (9, integral) pela API oficial. **`messages.log`, alertas e log de eventos de interoperabilidade por provedores nativos**

**História:** Como administrador, quero ver os eventos de todos os subsistemas em uma linha única, filtrável e ao vivo, para investigar um incidente sem abrir quatro arquivos e uma tabela.

**Contexto adicional:**
⚠️ **Este é o único eixo obrigatório sem cobertura na API oficial**, e portanto o principal vetor de diferenciação da submissão. A maioria das submissões vai entregar aqui o mínimo, porque exige trabalho próprio.

O requisito é, na prática, um problema de **normalização**. Cada origem tem formato próprio, e o portal define um esquema comum (RN-FD-23):

| Campo | Descrição |
|---|---|
| `timestamp` | Momento do evento, no fuso da instância |
| `source` | Origem: auditoria, journal, mensagens do sistema, alertas, interoperabilidade |
| `severity` | Severidade normalizada em escala única: info, warning, error, fatal |
| `namespace` | Namespace, quando a origem fornece |
| `process` | Identificador de processo, quando a origem fornece |
| `user` | Usuário associado, quando a origem fornece |
| `message` | Texto normalizado |
| `raw` | Registro original íntegro, sempre preservado |

O campo `raw` é obrigatório em toda origem: normalização nunca pode destruir informação (RN-FD-24).

Arquivos são lidos por leitura reversa paginada, a partir do fim, com limite de linhas. O portal jamais carrega um arquivo inteiro em memória (RN-FD-25).

Eventos com processo, namespace, usuário ou tarefa oferecem salto para a entidade correspondente, fechando o grafo entre logs e os demais domínios (RN-FD-26). O `CSPSessionID` do schema `Process` e os campos de auditoria dão material de correlação melhor do que uma leitura ingênua suporia.

**Fluxo Principal:**
1. Usuário acessa o fluxo de logs.
2. Sistema apresenta os eventos mais recentes das origens selecionadas, sob o esquema normalizado (RN-FD-23).
3. Usuário filtra por origem, severidade, período e texto livre.
4. Usuário ativa o acompanhamento ao vivo; novos eventos entram no topo.
5. Usuário abre um evento e inspeciona campos normalizados e registro original (RN-FD-24).
6. Usuário salta do evento para a entidade relacionada (RN-FD-26).
7. Usuário exporta o resultado filtrado.

**Fluxos Alternativos:**
- **A1** (2): origem indisponível ou inacessível por permissão. As demais seguem, e a indisponível é sinalizada com o motivo (RN-FD-32).
- **A2** (4): volume em tempo real acima do limite. Limitação de taxa, mantendo o mais recente e informando quantos eventos foram suprimidos.
- **A3** (3): filtro sem resultado. Propõe ampliar o período ou reduzir a severidade mínima.
- **A4** (5): registro original irrecuperável. Campos normalizados exibidos, com a lacuna sinalizada explicitamente.
- **A5** (2): auditoria desabilitada na instância, conforme `/v2/security/audit/enabled`. A origem aparece com o motivo e um caminho para habilitá-la.

**Regras:** RN-FD-23 a RN-FD-26, RN-FD-32.

```gherkin
1. Dado que eventos vêm de origens com formatos distintos
   Quando o fluxo unificado é exibido
   Então todos devem aparecer sob o mesmo esquema de campos
   E cada evento deve permitir acesso ao seu registro original

2. Dado que o usuário ativa o acompanhamento ao vivo
   Quando novos eventos ocorrem
   Então devem aparecer no topo sem recarregar a tela

3. Dado que a auditoria está desabilitada na instância
   Quando o fluxo é exibido
   Então as demais origens devem continuar funcionando
   E a origem de auditoria deve ser sinalizada com o motivo

4. Dado que um evento possui identificador de processo
   Quando o usuário abre esse evento
   Então deve existir salto direto para o processo correspondente
```

---

### UC10 — Aplicar mutação com dry-run, confirmação e trilha

**Ator:** Administrador
**Consome:** transversal a UC03, UC05, UC06, UC07 e UC08

**História:** Como administrador, quero ver exatamente o que vai mudar antes de aplicar, e ter o registro do que fiz.

**Contexto adicional:**
Existe como UC próprio para que a regra seja especificada uma vez e implementada como componente único, em vez de repetida por domínio. Com 273 operações, componente por domínio seria o erro mais caro do projeto.

Três graus de confirmação, escolhidos pela operação (RN-FD-04):

| Grau | Quando | Interação exigida |
|---|---|---|
| Simples | Criação e edição sem perda de acesso | Confirmar após ver as diferenças |
| Reforçado | Remoção, revogação, mudança que afeta terceiros ou o próprio usuário, suspensão do gerenciador de tarefas | Digitar o nome do objeto alvo |
| Máximo | Encerramento de processo, exclusão de coleção com segredos, operação irreversível | Digitar o identificador e reconhecer a consequência |

A trilha de sessão é local ao portal e à aba, não substitui a auditoria do IRIS, e a interface deixa isso explícito (RN-FD-27).

**Fluxo Principal:**
1. Usuário solicita uma mutação em qualquer domínio.
2. Sistema calcula o estado proposto e compara com o atual.
3. Sistema exibe as diferenças campo a campo, com valores anterior e novo.
4. Havendo efeito sobre terceiros, anexa a análise de impacto (RN-FD-11).
5. Sistema exige o grau de confirmação correspondente (RN-FD-04).
6. Usuário confirma; o sistema envia a mutação.
7. Sistema registra horário, alvo, diferenças e resultado na trilha.

**Fluxos Alternativos:**
- **A1** (2): o estado mudou no servidor desde a leitura. Recarrega, recalcula e exige nova confirmação, sem sobrescrever a mudança externa (RN-FD-31).
- **A2** (6): a API rejeita. Mensagem original exibida, formulário mantido, tentativa e falha registradas na trilha.
- **A3** (3): a mutação não produz diferença. Informa que não há mudança e não envia requisição.
- **A4** (7): usuário exporta a trilha em JSON, a qualquer momento.

**Regras:** RN-FD-03, RN-FD-04, RN-FD-11, RN-FD-12, RN-FD-27, RN-FD-31.

```gherkin
1. Dado que o usuário solicita uma mutação
   Quando a confirmação é exibida
   Então as diferenças entre estado atual e proposto devem aparecer campo a campo

2. Dado que a operação é destrutiva
   Quando a confirmação é exibida
   Então deve ser exigida a digitação do nome ou identificador do alvo

3. Dado que o estado mudou no servidor desde a leitura
   Quando o usuário tenta confirmar
   Então o sistema deve recarregar e recalcular as diferenças antes de aplicar

4. Dado que o usuário aplicou mutações na sessão
   Quando solicita a exportação da trilha
   Então deve receber JSON com horário, alvo, diferenças e resultado de cada ação
```

---

### UC11 — Instalar e provisionar

**Ator:** Avaliador do contest, ou administrador adotando a ferramenta
**Consome:** Docker Compose, IPM

**História:** Como avaliador, quero subir a aplicação com um comando e entrar direto em uma instância com dados de exemplo.

**Contexto adicional:**
Dois dos cinco critérios de julgamento publicados são Clarity of Instructions e Developer Experience. Este UC **é** esses dois critérios. Um avaliador que trava na instalação não avalia o produto.

Por isso o caminho padrão é um comando, sem edição de arquivo, sem variável obrigatória, com portas documentadas e conflito de porta tratado explicitamente no README.

O provisionamento cria, em instância nova, objetos de demonstração para que todas as telas tenham conteúdo desde o primeiro acesso: papéis, recursos, aplicação web de exemplo, tarefas, coleção de wallet quando disponível. Em instância existente, o provisionamento é **opcional e desligado por padrão** (RN-FD-29).

**Fluxo Principal:**
1. Usuário clona o repositório.
2. Usuário executa `docker compose up -d`.
3. Sistema sobe o IRIS Community, compila as classes e registra a aplicação web (RN-FD-28).
4. Sistema provisiona os objetos de demonstração.
5. Sistema informa URL e credenciais no log do contêiner.
6. Usuário acessa e entra.

**Fluxos Alternativos:**
- **A1** (2): porta em uso. README documenta a variável de sobrescrita e a mensagem esperada.
- **A2** (IPM): instalação em instância existente, sem provisionamento de demonstração.
- **A3** (3): falha de compilação. Erro legível no log do contêiner, sem exigir entrada no contêiner.
- **A4** (IRIS for Health): mesma imagem alternativa, sem alteração de procedimento.

**Regras:** RN-FD-28, RN-FD-29.

```gherkin
1. Dado um ambiente limpo com Docker disponível
   Quando o usuário executa docker compose up -d
   Então o portal deve ficar acessível sem nenhuma etapa manual adicional

2. Dado que a instalação terminou
   Quando o usuário acessa o portal pela primeira vez
   Então todas as telas de domínio devem conter dados de demonstração

3. Dado que o usuário instala via IPM em instância existente
   Quando a instalação termina
   Então nenhum objeto de demonstração deve ter sido criado sem consentimento

4. Dado que a instalação é feita sobre a imagem IRIS for Health Community
   Quando o portal é acessado
   Então todos os domínios devem funcionar sem alteração de procedimento
```

---

## 8. Catálogo de regras de negócio (`RN-FD`)

| ID | Regra | Enunciado | UCs |
|---|---|---|---|
| RN-FD-01 | Identidade delegada | Sem base de usuários própria, sem senha armazenada, sem credencial em cache no cliente ou no servidor. Toda operação executa sob a identidade e os papéis do usuário autenticado. Nenhum caminho de fallback de autenticação pode violar isso | UC01 |
| RN-FD-02 | Capacidade derivada da especificação | O mapa de capacidades da sessão é derivado do privilégio que cada operação da SysAdmin API declara, cruzado com os privilégios do usuário. Nunca uma tabela codificada à mão. Ação sem privilégio aparece desabilitada com o recurso e a permissão exigidos, nunca oculta | UC01, todos |
| RN-FD-03 | Modo seguro por padrão | Toda sessão inicia somente leitura. Desarme explícito, **por aba do navegador**, nunca compartilhado entre abas e nunca persistido. Cada aba nova nasce armada, inclusive duplicata de aba desarmada | UC01 a UC08, UC10 |
| RN-FD-04 | Graus de confirmação | Simples, reforçado (digitar o nome do alvo) e máximo (digitar o identificador e reconhecer a consequência). O grau é determinado pela operação, não pelo domínio | UC10 |
| RN-FD-05 | Índice duplo da paleta | Indexa entidades (servidor, com debounce) e ações (local), agrupa por domínio e exibe o contexto que desambigua homônimos | UC02 |
| RN-FD-06 | Resiliência da paleta | Falha da busca de entidades não desabilita a paleta: ações locais seguem disponíveis, com a parte indisponível sinalizada | UC02 |
| RN-FD-07 | Exposição visível na lista | A listagem de aplicações web sinaliza visualmente as acessíveis sem autenticação | UC03 |
| RN-FD-08 | Executor REST confinado | O destino das requisições de teste deriva da instância corrente, nunca do cliente. O portal não é proxy de requisições externas. Ponto explicitado no README | UC04 |
| RN-FD-09 | Descoberta dupla e auto-inclusão | Cobre serviços com e sem especificação, sinalizando a ausência. A própria API do FlightDeck aparece entre os descobertos | UC04 |
| RN-FD-10 | Privilégio com procedência | Todo privilégio efetivo exibido vem com a cadeia que o concede. Nunca o resultado sem a origem | UC05 |
| RN-FD-11 | Impacto antes da remoção | Toda remoção ou revogação em segurança executa análise de impacto antes da confirmação, listando usuários e objetos afetados | UC05, UC10 |
| RN-FD-12 | Autoproteção | Bloqueia operações que removeriam o último acesso administrativo, desabilitariam a aplicação web que serve o portal, ou encerrariam o processo da própria sessão. O bloqueio é sempre explicado | UC03, UC05, UC08, UC10 |
| RN-FD-13 | Grafo de entidades | Toda entidade expõe vínculos de entrada e saída, com navegação em um clique entre domínios. Modelo de navegação secundário, complementar à paleta | UC03 a UC06, UC09 |
| RN-FD-14 | Segredo nunca legível | Material secreto nunca é exibido, retornado por API do portal ou registrado em log. Apenas definir, substituir e excluir | UC06 |
| RN-FD-15 | Ciclo de vida temporal | Itens com validade exibem dias restantes, faixas de estado, e os críticos são agregados no painel inicial | UC06 |
| RN-FD-16 | Teste de conexão | Configurações TLS oferecem teste sob demanda, exibindo a resposta original sem reinterpretação | UC06 |
| RN-FD-17 | Histórico compacto | A listagem de tarefas exibe o histórico recente de forma compacta, permitindo ver falha intermitente sem abrir o detalhe | UC07 |
| RN-FD-18 | Execução sem concorrência | Execução sob demanda bloqueada quando já existe execução corrente da mesma tarefa, com o horário de início informado | UC07 |
| RN-FD-19 | Conjunto mínimo de instrumentos | O painel cobre, no mínimo, CPU, memória, disco por banco, processos e dispositivos. Ausência de qualquer um é falha de requisito | UC08 |
| RN-FD-20 | Streaming com queda e pausa | SSE quando disponível, queda automática para polling, frequência configurável, pausa automática ao perder o foco. O modo em uso é sempre visível | UC08 |
| RN-FD-21 | Sem persistência de métricas | O portal não persiste histórico de métricas. A janela deslizante vive na sessão do cliente. Retenção é responsabilidade de ferramenta de observabilidade | UC08 |
| RN-FD-22 | Encerramento é grau máximo | Encerramento de processo é sempre destrutivo de grau máximo, sem exceção por perfil | UC08, UC10 |
| RN-FD-23 | Esquema normalizado de log | Todas as origens mapeadas para o esquema comum, com severidade convertida para escala única | UC09 |
| RN-FD-24 | Original preservado | Normalização nunca descarta informação. O registro original é preservado em `raw` e acessível. Ausência sinalizada explicitamente | UC09 |
| RN-FD-25 | Leitura reversa paginada | Arquivos lidos a partir do fim, por páginas com limite de linhas. Nunca carregar arquivo inteiro em memória | UC09 |
| RN-FD-26 | Correlação log para entidade | Eventos com processo, namespace, usuário ou tarefa oferecem salto direto para a entidade | UC07, UC09 |
| RN-FD-27 | Dry-run e trilha | Toda mutação exibe diferenças antes de aplicar e é registrada na trilha com horário, alvo, diferenças e resultado. Trilha local à aba, exportável em JSON, com aviso explícito de que não substitui a auditoria do IRIS | UC03, UC05 a UC08, UC10 |
| RN-FD-28 | Compatibilidade e instalação | Funciona em IRIS CE e IRIS4H CE, com instalação em um comando e sem etapa manual adicional | UC11 |
| RN-FD-29 | Demonstração consentida | Objetos de demonstração criados automaticamente apenas na instalação por contêiner. Por IPM em instância existente, opcional e desligado por padrão | UC11 |
| RN-FD-30 | API oficial primeiro | Onde a SysAdmin API existe, ela é usada. Nenhum endpoint que ela já fornece é reimplementado sobre classes. Provedores nativos existem apenas para o que ela não cobre: logs e CPU/memória do host (`/proc/stat`, `/proc/meminfo`), conforme a constitution v2.0.0. A regra governa o portal em execução; o bootstrap do instalador é exceção estreita registrada no plano | Todos |
| RN-FD-31 | Concorrência otimista | Se o estado mudou no servidor entre a leitura e a confirmação, recarrega, recalcula e exige nova confirmação, em vez de sobrescrever a mudança externa. Mesmo caminho de código usado na expiração de sessão | UC01, UC10 |
| RN-FD-32 | Degradação graciosa e assincronia | Recurso indisponível na versão ou edição aparece desabilitado com motivo e versão mínima. Dado que chega por tarefa assíncrona mantém o último valor conhecido visível enquanto atualiza, nunca apaga o número nem o troca por indicador de carregamento | UC06, UC07, UC08, UC09 |
| RN-FD-33 | Sonda de instância | `GET /info` é a fonte de versão, edição e privilégios. Detecção de capacidade nunca se baseia em análise de string de versão quando a API oferece a resposta | UC01 |
| RN-FD-34 | A API decide o permitido | Quando o schema declara capacidade de uma operação sobre um objeto (`CanBeTerminated`, `CanBeSuspended`, `CanReceiveBroadcast`), esses campos governam diretamente o estado do controle. A interface nunca infere permissão por tipo, usuário ou estado | UC08 |

---

## 9. Mensagens de erro e validação

| Nº | Cenário | UC | Texto proposto (inglês) |
|---|---|---|---|
| 1 | Credencial inválida | UC01 A1 | *"Invalid credentials. Check your username and password."* |
| 2 | Falta de privilégio | UC01, todos | *"Requires [PERMISSION] on [RESOURCE]. Ask your instance administrator for access."* |
| 3 | Mutação com modo seguro armado | UC02 a UC08 | *"Safe mode is on. Turn it off to make changes in this tab."* |
| 4 | Desabilitar a aplicação do portal | UC03 A4 | *"This web application serves FlightDeck. Disabling it would lock you out."* |
| 5 | Último acesso administrativo | UC05 A1 | *"This change would remove the last administrative access to this instance. Operation blocked."* |
| 6 | Mudança afeta o próprio usuário | UC05 A2 | *"This change affects your own account and may take effect immediately. Type the target name to confirm."* |
| 7 | Tentativa de leitura de segredo | UC06 A2 | *"Secret values are never displayed. You can replace or delete this secret."* |
| 8 | Recurso indisponível na versão | UC06 A1, UC08 A5, UC09 A1 | *"Not available on this IRIS version or edition. Requires [VERSION]."* |
| 9 | Execução concorrente de tarefa | UC07 A1 | *"This task is already running since [TIME]. Wait for it to finish before running it again."* |
| 10 | Suspensão do gerenciador de tarefas | UC07 A5 | *"Suspending the task manager stops every scheduled task on this instance. Type the instance name to confirm."* |
| 11 | Confirmação de encerramento | UC08 passo 7 | *"Terminating process [PID] cannot be undone. Type the process ID to confirm."* |
| 12 | Processo da própria sessão | UC08 A3 | *"This is the process running your FlightDeck session. Operation blocked."* |
| 13 | Operação negada pelo schema | UC08 A6 | *"The server reports this process cannot be terminated."* |
| 14 | Limitação de taxa em logs ao vivo | UC09 A2 | *"Showing the most recent events. [N] events were suppressed while the stream was saturated."* |
| 15 | Filtro de logs sem resultado | UC09 A3 | *"No events match these filters. Try widening the time range or lowering the minimum severity."* |
| 16 | Auditoria desabilitada | UC09 A5 | *"Auditing is disabled on this instance, so no audit events are available."* |
| 17 | Estado alterado durante a edição | UC10 A1 | *"This object changed on the server while you were editing. Review the updated differences before applying."* |
| 18 | Mutação sem diferença | UC10 A3 | *"Nothing to apply. The proposed state matches the current one."* |
| 19 | Busca de entidades indisponível | UC02 A3 | *"Entity search is unavailable right now. Portal actions are still available."* |

Revisão obrigatória em passe único antes da gravação do vídeo.

---

## 10. Arquitetura

### 10.1 Camadas

| Camada | Tecnologia | Responsabilidade |
|---|---|---|
| Interface | React 18, TypeScript, Vite. Build estático servido pelo IRIS | Navegação, paleta, instrumentos, formulários, dry-run, trilha |
| API do portal | ObjectScript REST sob especificação OpenAPI | Superfície única consumida pela interface, auto-documentada (RF12) |
| Composição | ObjectScript | Privilégio efetivo, grafo, análise de impacto, diferenças, autoproteção |
| Provedores nativos | ObjectScript | **Apenas o que a SysAdmin API não cobre: `messages.log`, alertas, log de interoperabilidade, e CPU/memória do host** |
| Plataforma | SysAdmin API `/api/admin` mais IRIS | 273 operações oficiais, autenticação, autorização, dados |

```
React  →  FlightDeck API  →  ┬→  /api/admin/v2   (273 ops, oficial)
                             ├→  /api/mgmnt/     (explorador REST, UC04)
                             └→  provedores nativos (logs; CPU e memória do host)
```

**Por que existe um backend próprio**, e não chamada direta do navegador:

1. Logs não existem na API oficial. Alguém tem que implementá-los.
2. Composição. Privilégio efetivo, grafo e impacto exigem várias chamadas combinadas. No navegador, viraria cascata de requisições e interface lenta.
3. Autoproteção (RN-FD-12) precisa ser server-side. Regra que vive no cliente não é regra.
4. Dry-run exige leitura fresca imediatamente antes da aplicação, junto com RN-FD-31.
5. RF12 exige que a API do FlightDeck exista com especificação própria.

**RN-FD-30 é a regra de ouro:** onde a API oficial existe, use-a. O backend encaminha e compõe, não reescreve.

### 10.2 Stack de interface

| Camada | Escolha | Justificativa |
|---|---|---|
| Base | React 18, TypeScript, Vite | Build estático, sem runtime adicional |
| Estilo | Utilitário sobre os tokens de `03-DESIGN.md` | Dois temas por troca de variáveis na raiz. Nenhum hexadecimal literal em componente |
| Primitivas | Biblioteca sem estilo, com acessibilidade nativa | Meta WCAG AA sem reimplementar comportamento |
| Estado de servidor | Cliente de consulta com cache e invalidação | Base do dry-run e da concorrência otimista |
| Paleta | Componente dedicado, filtragem local mais fonte assíncrona | Abrir abaixo de cem milissegundos mesmo com busca pendente |
| Listas longas | Virtualização de linhas | Processos e eventos de log sem degradação |
| Séries temporais | **Canvas** | ⚠️ Requisito. Biblioteca declarativa em SVG degrada com atualização a cada segundo |
| Conteúdo técnico | Editor leve para JSON, OpenAPI e log bruto | Realce e dobra, sem o peso de um editor completo |

### 10.3 Ambiente

Integralmente em WSL2, com Docker Engine nativo, sem Docker Desktop. Repositório em `/mnt/d/Projetos/iris-flightdeck`. Configuração completa em `05-GUIA-spec-kit.md`, Seção 1.

⚠️ `/mnt/d` é disco do Windows montado via DrvFs, não o sistema de arquivos nativo do WSL. Três consequências, com mitigação obrigatória:

- **Permissões.** Sem metadados Unix, `chmod` não tem efeito e o processo do IRIS pode falhar ao escrever. Mitigação: `metadata` no automount, e **dados duráveis do IRIS em volume nomeado do Docker**, nunca em bind a partir de `/mnt/d`.
- **I/O.** Lento em muitos arquivos pequenos, que é o padrão de compilação ObjectScript e de build do frontend. Parcialmente inevitável.
- **`inotify` indisponível.** O watch do Vite não recarrega sozinho. Mitigação: polling no servidor de desenvolvimento.

Essas mitigações entram no `docker-compose.yml` e no `vite.config.ts` desde o dia 1, não depois.

---

## 11. Requisitos não funcionais

- **Desempenho de interface.** Primeira renderização útil abaixo de dois segundos em instância local. Paleta abre abaixo de cem milissegundos, sempre.
- **Desempenho de listagem.** Paginação no servidor em todas as listagens. Nenhuma tela carrega coleção completa sem limite.
- **Telemetria.** Frequência configurável, valor inicial conservador, pausa automática por perda de foco.
- **Segurança.** Nenhuma credencial armazenada em qualquer camada (RN-FD-01). Nenhum segredo trafega de volta ao cliente (RN-FD-14). Executor REST confinado (RN-FD-08). Autorização delegada ao IRIS.
- **Compatibilidade.** IRIS CE e IRIS4H CE nas versões correntes das imagens Community. Recursos ausentes degradam graciosamente.
- **Tipografia empacotada.** IBM Plex Sans e IBM Plex Mono auto-hospedadas, subconjunto latino. **Nenhuma fonte de CDN**: o portal precisa funcionar sem saída para a internet.
- **Temas.** Escuro e claro, alternáveis no glareshield, tema inicial herdado do sistema operacional, escolha explícita persistida por usuário.
- **Acessibilidade.** WCAG 2.1 AA, verificado nos dois temas, cada um com suas variantes semânticas.
- **Navegadores.** Versões correntes de Chromium, Firefox e Safari.
- **Responsividade.** Funcional a partir de 1280px. Abaixo disso o inspetor vira sobreposição. Celular não é objetivo.
- **Observabilidade própria.** Erros de backend registrados com correlação para a requisição de origem, sem conteúdo sensível.
- **Licenciamento.** MIT, com arquivo de licença no repositório.

---

## 12. Fora de escopo

- Explorador de SQL, explorador de classes, editor de código e ferramentas de desenvolvimento.
- Configuração e monitoramento de produções de interoperabilidade. Apenas o log de eventos entra, como origem do UC09.
- Espelhamento e sharding, além do que a SysAdmin API expõe em ECP.
- Backup e restauração. Journal entra apenas pelas operações oficiais e como origem de log.
- Persistência e retenção de métricas históricas (RN-FD-21).
- Administração de múltiplas instâncias. O FlightDeck administra a instância onde está instalado.
- Idiomas além do inglês.
- Aplicativo móvel ou layout otimizado para celular.

---

## 13. Plano de entrega

### 13.1 Janela e capacidade

14/09 a 27/09/2026, meta interna de submissão em 26/09. Um desenvolvedor, faseamento estritamente sequencial, sem paralelização por domínio.

### 13.2 Faseamento

- **Dia 1, primeira metade.** Tokens completos nos dois temas, alternador, fontes empacotadas, extraídos de `03-DESIGN.md` e `prototype.html`.
- **Dia 1, segunda metade.** Roteiro de verificação (Seção 14). **A verificação de autenticação é bloqueante para o UC01.**
- **Dia 2.** Concha: glareshield, rail, geometria lista mais inspetor com abas de seção, paleta. UC01 e UC02. Docker Compose e IPM.
- **Dias 3 e 4.** UC03 e UC04, mais o componente transversal de mutação do UC10. Ao fim, o padrão replicável de tela de domínio está fechado, e nenhum domínio posterior exige decisão de design.
- **Dias 5 e 6.** UC05 (31 operações) e UC06 (89 operações). Maior volume e maior peso em Complexity.
- **Dias 7 e 8.** UC07 (24 operações) e UC08 (102 operações), com atenção ao padrão assíncrono do disco e aos campos de capacidade do processo.
- **Dias 9 a 12.** UC09, quatro dias. É trabalho próprio, é o único eixo sem cobertura oficial, e é o diferencial competitivo. Painel inicial preenchido com itens de atenção de todos os domínios. Provisionamento de demonstração.
- **Dia 13.** Revisão contra a lista de anti-padrões de `03-DESIGN.md` Seção 7, tela por tela, nos dois temas, reservada como duas horas de tarefa. Passe de textos (Seção 9). README em inglês com link para a ideia. Gravação do vídeo. Submissão.
- **28/09 a 04/10.** Artigo na Developer Community, correções apontadas pela comunidade, melhorias permitidas pelo regulamento.

### 13.3 Regra de corte

Se um bloco estourar, o corte recai sobre **profundidade nos domínios cobertos pela API oficial**, que degradam para mapeamento simples sem perder cobertura dos seis eixos.

**Logs nunca é cortado.** É o único eixo onde o corte custa diferenciação, e não apenas polimento.

**Nunca cortar, em nenhuma circunstância:** os tokens dos dois temas, o numeral tabular, o anel de foco, a orquestração do dry-run, o canvas do cluster de instrumentos, e o dia e meio de README, instalação e vídeo.

---

## 14. Roteiro de verificação do dia 1

Em ordem de importância. Produz um relatório de disponibilidade que alimenta RN-FD-32 e o planejamento das features seguintes.

1. **`/api/admin` existe e responde** nas duas imagens Community, e em qual versão de IRIS. Se não existir, todo o desenho muda.
2. **Qual caminho de autenticação funciona sem armazenar credencial.** Três candidatos, nesta ordem: chamada em processo sob o usuário autenticado na aplicação web; JWT quando a instância for 2026.2 ou superior; proxy em loopback aceitando o cookie de sessão CSP. **Bloqueante para o UC01.**
3. **Forma real de `SystemResourcesStats` e `SharedMemoryUsage`**, não declarada na especificação.
4. **Ciclo assíncrono de métricas de banco.** Disparar, consultar `/v2/async-result`, medir latência típica. Define o comportamento do instrumento de disco.
5. **`/v2/wallet/*` responde** na imagem Community.
6. **`/api/mgmnt/` disponível**, já que o UC04 não é coberto pela SysAdmin API.
7. **Caminho e formato do `messages.log`**, arquivo de alertas e consulta do log de eventos de interoperabilidade. Insumo direto do UC09.
8. **`/v2/security/audit/enabled`** na imagem, para saber se a origem de auditoria estará disponível na demonstração.

O script não aborta no primeiro erro: roda todas as sondas, classifica cada uma em `confirmed_present`, `confirmed_absent` ou `inconclusive`, registra o erro bruto, e sai com código diferente de zero se sobrar qualquer inconclusivo. Uma sonda inconclusiva bloqueia o planejamento do domínio correspondente e **nunca** vira mensagem de degradação para o usuário.

---

## 15. Riscos

| # | Item | Tipo | Observação |
|---|---|---|---|
| 1 | Autenticação sem armazenar credencial em instância anterior a 2026.2 | **Risco número 1** | Os endpoints JWT exigem 2026.2. Sobra `basicAuth`, que colide com RN-FD-01. Três caminhos candidatos na Seção 14. Está no caminho crítico do UC01 |
| 2 | 273 operações mais provedores nativos de log em treze dias, em solo | Risco de escopo | Mitigado pelo padrão replicável fechado nos dias 3 e 4, e pela regra de corte da Seção 13.3 |
| 3 | Bônus de tecnologia ainda não anunciados | Risco competitivo | Acompanhamento diário obrigatório. Podem exigir decisão arquitetural se saírem tarde |
| 4 | Schemas sem forma declarada | Dependência técnica | `SystemResourcesStats` e `SharedMemoryUsage`. Sondar antes de tipar, nunca inventar campos |
| 5 | Latência do ciclo assíncrono de disco | Risco de experiência | Se for alta, o instrumento de disco atualiza em cadência menor que os demais. Aceitável, desde que declarado na interface |
| 6 | Diferença entre IRIS CE e IRIS4H CE | Risco de compatibilidade | Mitigado por RN-FD-32 e por teste obrigatório nas duas imagens antes da submissão |
| 7 | Dois temas dobram verificação de contraste | Risco de prazo assumido | Decisão consciente. Mitigado por disciplina estrita de token: uma cor literal quebra um dos temas |
| 8 | Volume e formato do `messages.log` variando entre versões | Risco técnico | Mitigado pelo `raw` obrigatório: falha de normalização degrada a experiência, nunca perde informação |
| 9 | Executor REST interpretado como vetor de requisição arbitrária | Risco de segurança | Mitigado por RN-FD-08. Precisa ser explicado no README |
| 10 | Concorrência cobrindo os mesmos 273 endpoints | Risco competitivo | A diferenciação declarada é experiência e logs, não cobertura. README e vídeo precisam liderar por esse ângulo |
| 11 | Trilha de sessão confundida com auditoria | Risco de comunicação | Mitigado por aviso explícito na interface |
| 12 | Qualidade do vídeo e do README | Risco de avaliação | Dois dos cinco critérios publicados. Dia e meio reservado, não negociável |
| 13 | Freshmen Nomination | Esclarecimento | Inelegível pelo 3º lugar em Experts no contest #46 |

---

## 16. Critérios de aceite

Escopo:

- [ ] Os seis eixos implementados, com operação real de leitura e mutação
- [ ] As 273 operações da SysAdmin API atribuídas e implementadas, ou explicitamente degradadas com motivo
- [ ] Logs com no mínimo cinco origens sob esquema normalizado, sempre com registro original acessível
- [ ] A API do próprio FlightDeck aparece no explorador do FlightDeck

Comportamento:

- [ ] Toda sessão inicia em modo seguro, e cada aba nova nasce armada
- [ ] Toda mutação exibe diferenças antes de aplicar; ações destrutivas exigem digitação do alvo
- [ ] Remoções em segurança apresentam análise de impacto antes da confirmação
- [ ] Nenhuma credencial armazenada e nenhum material secreto exibido, em nenhum caminho
- [ ] O portal bloqueia operações que o desligariam ou removeriam o último acesso administrativo
- [ ] Campos de capacidade da API governam o estado dos controles
- [ ] Recursos indisponíveis aparecem desabilitados com motivo, sem quebrar tela
- [ ] Dado assíncrono mantém o último valor visível durante a atualização

Qualidade:

- [ ] Revisão contra a lista de anti-padrões de `03-DESIGN.md` Seção 7 sem defeito aberto
- [ ] Nenhum hexadecimal literal em componente, verificado por varredura
- [ ] Os dois temas funcionam em todas as telas, com contraste verificado em ambos
- [ ] WCAG 2.1 AA e operação completa por teclado

Submissão:

- [ ] Instalação em um comando em ambiente limpo, verificada nas duas imagens Community
- [ ] Todas as telas com conteúdo no primeiro acesso
- [ ] README em inglês, com passos de instalação e link para a ideia
- [ ] Licença MIT, vídeo publicado, submissão aceita pela moderação
- [ ] Bônus de tecnologia conferidos e endereçados
