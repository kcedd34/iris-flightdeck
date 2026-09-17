# Especificação de Design — FlightDeck for InterSystems IRIS

**Documento de design do FlightDeck.** Acompanha o PRD v2.0 e é a fonte única de design.
**Versão:** 2.0
**Destino:** insumo direto da `constitution` do Spec-Kit, antes de qualquer `/specify` de tela.

---

## 1. Por que esta especificação existe

A Seção 9 do PRD descreve o design em adjetivos: neutro, escuro, denso, funcional. Adjetivo não gera interface. Gera o padrão da biblioteca de componentes, que é exatamente o que qualquer projeto assistido por IA produz hoje, e o que um júri de experts já viu dezenas de vezes.

Este documento troca adjetivo por valor. Toda decisão abaixo é um número, um hex ou uma regra verificável. O objetivo é que, no dia 3, não exista nenhuma decisão estética a tomar: só execução.

**Premissa de prazo.** Treze dias, um desenvolvedor, seis domínios obrigatórios. A estratégia é concha convencional e impecável, com dois momentos assinatura especificados ao detalhe. Ousadia distribuída produz inconsistência, e inconsistência lê como amadorismo, não como autoria.

---

## 2. Direção: instrumento, não marca

O conceito é o glass cockpit da aviação comercial, e ele não é decorativo. A aviação resolveu, ao longo de décadas e sob consequência real, o mesmo problema que um portal de administração tem: apresentar muitos valores simultâneos, deixar claro o que é normal e o que exige ação, e distinguir o que o sistema **está fazendo** do que o operador **mandou fazer**.

Dessa disciplina vêm três decisões que definem o produto inteiro:

**1. Cor é código, nunca identidade.** A aviação usa cor com significado fixo: vermelho exige ação imediata, âmbar exige atenção, verde é estado real e normal, magenta é valor comandado pelo operador, ciano é referência selecionada. O FlightDeck adota essa gramática literalmente. A consequência é dura e é o ponto: **o produto não tem cor de marca**. Nenhum botão, cabeçalho ou logo usa cor decorativa. Se uma cor aparece na tela, ela significa alguma coisa.

**2. A distinção verde e magenta vira o dry-run.** No cockpit, verde é o valor atual e magenta é o valor comandado, ainda não atingido. Essa é, sem adaptação nenhuma, a semântica do RN-FD-27: estado atual contra estado proposto. O dry-run do FlightDeck não inventa uma linguagem visual; ele herda uma que já existe e já foi validada em ambiente crítico.

**3. Ação primária é acromática.** Como cor pertence ao significado, o botão de ação primária não pode roubá-la. Ele é preenchido com a cor de texto de maior contraste, osso sobre grafite. Incomum em interface de produto, e inteiramente coerente com a regra acima.

**O que isso rejeita explicitamente:** painel escuro com um acento neon como identidade visual, gradiente decorativo, cartões arredondados idênticos com a mesma sombra suave, e a estética de biblioteca de componentes recém-instalada.

---

## 3. Tokens

### 3.1 Cor

**Dois temas são entregues**, escuro e claro. O escuro é o padrão de desenho: todas as decisões de hierarquia nasceram nele. O claro é uma tradução disciplinada do mesmo sistema, não um segundo design.

#### Tema escuro (padrão)

Superfícies com cast frio esverdeado. Não é preto tingido: há croma visível, e é o que separa esta interface de um tema escuro genérico.

| Token | Hex | Uso |
|---|---|---|
| `surface-canvas` | `#101619` | Fundo da aplicação |
| `surface-panel` | `#171F24` | Painéis, listas, cabeçalhos de tabela |
| `surface-float` | `#1E282E` | Camadas flutuantes: paleta, diálogo, menu |
| `line-hairline` | `#2A363D` | Separadores estruturais, 1px |
| `line-strong` | `#3A4A53` | Borda de campo, borda de camada flutuante |
| `text-primary` | `#E6EDF0` | Texto principal, valor de instrumento, botão primário |
| `text-secondary` | `#93A3AC` | Rótulos, metadados, coluna secundária |
| `text-muted` | `#5E6E77` | Desabilitado, marca de posição, valor ausente |

Semânticas, com significado fixo em toda a aplicação.

| Token | Hex | Significado. Sem exceção |
|---|---|---|
| `state-actual` | `#5FBF8B` | Estado real e normal. Valor vigente no servidor |
| `state-commanded` | `#DD7AC8` | Valor proposto, ainda não aplicado. Exclusivo do dry-run |
| `state-caution` | `#E8B04B` | Atenção. Ação necessária, não imediata |
| `state-warning` | `#E5574E` | Alerta. Ação imediata ou operação destrutiva |
| `state-selected` | `#6CC7D9` | Seleção, foco e referência ativa. Cor do anel de foco |

**Regras de uso, verificáveis em revisão de código:**

- Nenhuma das cinco cores semânticas aparece em superfície, borda estrutural, ícone de navegação ou botão sem estado.
- Nenhuma cor fora desta tabela entra no código. Sem exceção para ilustração, vazio ou onboarding.
- Cor nunca é o único portador de significado. Todo estado carrega também ícone e rótulo textual, por acessibilidade e porque vídeo comprimido destrói distinção cromática sutil.
- O anel de foco é `state-selected`, 2px, com deslocamento de 2px, e nunca é suprimido.

#### Tema claro

A tradução obedece a uma inversão de relação, não de valores. No escuro, o canvas é a superfície mais escura e os painéis se destacam por ficarem mais claros. No claro, o canvas é levemente acinzentado e os painéis se destacam por ficarem mais brancos. A ordem de luminância se inverte, a hierarquia permanece idêntica.

| Token | Hex | Uso |
|---|---|---|
| `surface-canvas` | `#E9EDEF` | Fundo da aplicação. Papel frio, nunca creme |
| `surface-panel` | `#F6F8F9` | Painéis, listas, cabeçalhos de tabela |
| `surface-float` | `#FFFFFF` | Camadas flutuantes |
| `line-hairline` | `#D2DADE` | Separadores estruturais, 1px |
| `line-strong` | `#B4C0C6` | Borda de campo, borda de camada flutuante |
| `text-primary` | `#111A1F` | Texto principal, valor de instrumento, botão primário |
| `text-secondary` | `#4A5B64` | Rótulos, metadados, coluna secundária |
| `text-muted` | `#7B8A92` | Desabilitado, marca de posição, valor ausente |

⚠️ **As cores semânticas não são reaproveitadas entre temas.** As cinco cores de cockpit foram calibradas para fundo escuro. Sobre superfície clara, todas falham o contraste mínimo de 4.5 para texto. O tema claro usa variantes escurecidas e mais saturadas, preservando o matiz e o significado:

| Token | Claro | Escuro, para comparação | Significado |
|---|---|---|---|
| `state-actual` | `#1E7A4F` | `#5FBF8B` | Estado real e normal |
| `state-commanded` | `#A8329B` | `#DD7AC8` | Valor proposto, exclusivo do dry-run |
| `state-caution` | `#8A5A00` | `#E8B04B` | Atenção |
| `state-warning` | `#C0342B` | `#E5574E` | Alerta e operação destrutiva |
| `state-selected` | `#0E6E80` | `#6CC7D9` | Seleção, foco e anel de foco |

**Regras específicas dos dois temas:**

- Nenhum componente conhece hexadecimal. Todo valor vem de variável de tema, e trocar de tema é trocar o conjunto de variáveis na raiz. Componente com cor literal é defeito.
- **A regra acromática da ação primária se mantém e se inverte sozinha.** No escuro, o botão primário é osso sobre grafite. No claro, é quase preto sobre branco. Em ambos, é `text-primary` preenchendo e `surface-canvas` no texto. A mesma regra, o mesmo código.
- O traço da série temporal usa `state-actual` do tema ativo, lido em tempo de desenho e não em tempo de montagem, para que a troca de tema repinte o canvas sem recriar o instrumento.
- O tema inicial segue a preferência do sistema operacional. A escolha explícita do usuário prevalece e é persistida por usuário.
- O alternador vive no glareshield, à direita, ao lado do indicador de modo. Não é enterrado em tela de preferências: é controle de conforto de leitura, usado em mudança de ambiente.

⚠️ **Custo aceito.** Dois temas dobram a verificação de contraste e a revisão visual. A decisão foi tomada conscientemente. A contrapartida de engenharia é que a disciplina de token deixa de ser boa prática e passa a ser condição de funcionamento: uma única cor literal em componente quebra um dos dois temas, provavelmente o que você não está olhando.

### 3.2 Tipografia

**IBM Plex Sans** para interface e **IBM Plex Mono** para tudo que é literal do sistema. A escolha não é neutra: Plex nasceu de um vernáculo de engenharia corporativa, tem desenho levemente mecânico e evita o ar de produto genérico que a família padrão de toda interface moderna carrega hoje.

Ambas são auto-hospedadas no pacote, com subconjunto latino. **Nenhuma fonte vem de CDN**, porque o portal precisa funcionar em instância sem saída para a internet, cenário comum em ambiente de administração.

| Papel | Família | Tamanho | Peso | Entrelinha |
|---|---|---|---|---|
| Leitura de instrumento | Plex Sans | 40px | 500 | 1.0 |
| Título de tela | Plex Sans | 24px | 500 | 1.2 |
| Título de painel | Plex Sans | 18px | 500 | 1.3 |
| Corpo e rótulo de campo | Plex Sans | 15px | 400 | 1.5 |
| Interface densa, tabela, lista | Plex Sans | 13px | 400 | 1.4 |
| Rótulo secundário, unidade, metadado | Plex Sans | 12px | 400 | 1.3 |
| Identificador técnico | Plex Mono | 13px | 400 | 1.4 |
| Conteúdo de log e JSON | Plex Mono | 12px | 400 | 1.5 |

**Regras:**

- Monoespaçado é obrigatório e exclusivo para o que é literal do sistema: nome de classe, caminho de API, identificador de processo, nome de recurso, conteúdo de log, JSON, comando. Nunca para rótulo de interface.
- `font-variant-numeric: tabular-nums` em toda coluna numérica, todo instrumento e todo carimbo de tempo. Número que dança ao atualizar é o detalhe que separa refinado de apressado, e custa uma linha de CSS.
- Sentença capitalizada em todo rótulo. **Nada em caixa alta**, incluindo rótulos de coluna e etiquetas de estado.
- Comprimento de linha em texto corrido limitado a 72 caracteres.

### 3.3 Espaçamento, raio e elevação

Base de 4px. Passos permitidos: 4, 8, 12, 16, 24, 32, 48. Nenhum valor fora da escala.

**Raio codifica hierarquia**, em vez de ser um valor único aplicado a tudo:

| Raio | Onde | Por quê |
|---|---|---|
| `0` | Painéis, tabelas, linhas, instrumentos | Estrutura é retangular. Instrumento não tem canto arredondado |
| `2px` | Campos, botões, etiquetas | Controle é manipulável, e o raio mínimo sinaliza isso |
| `6px` | Paleta, diálogo, menu, dica | Somente o que flutua acima da estrutura |

**Elevação existe apenas em camada flutuante.** Superfície estrutural não tem sombra nenhuma: ela se distingue por luminância e por fio de 1px. Camada flutuante recebe borda `line-strong` de 1px mais `0 16px 48px rgba(0,0,0,.55)`. Uma única definição de sombra em todo o produto.

### 3.4 Movimento

Um momento orquestrado, e só um: **a revelação do dry-run** (Seção 6). Fora dele:

- Instrumentos não animam, **movem**. A série temporal desliza porque o tempo passa, em fluxo contínuo, sem transição de entrada.
- Movimento responde a ação: abrir, expandir, confirmar. 120ms para camada, 90ms para estado de controle, curva `cubic-bezier(.2,0,0,1)`.
- **Proibido:** entrada com desvanecer e subir em seção ou cartão, elevação em passagem do cursor, deslocamento de conteúdo em foco, qualquer transição maior que 200ms.
- `prefers-reduced-motion` desliga tudo, inclusive a revelação do dry-run, que passa a ser troca de estado instantânea.

---

## 4. Layout

Três zonas fixas. A geometria é sempre a mesma, em todos os seis domínios.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ GLARESHIELD  44px  fixo, sempre visível                                      │
│ IRIS 2026.1 CE · IRISAPP   CPU 34%  MEM 61%  DSK 72%      [SAFE MODE]  kadu  │
├────┬─────────────────────────────────────────────────────────────────────────┤
│    │  Web applications                                    [Search]  [New]    │
│ R  ├──────────────────────────────────────┬──────────────────────────────────┤
│ A  │  LISTA                    min 480px  │  INSPETOR              420px     │
│ I  │                                      │                                  │
│ L  │  /csp/flightdeck      IRISAPP   ●    │  /csp/flightdeck                 │
│    │  /api/mgmnt           %SYS     ●     │  Enabled · Password auth         │
│ 56 │  /csp/sys             %SYS     ●     │                                  │
│ px │  /api/monitor         %SYS     ▲     │  Resource   %Admin_Manage        │
│    │                                      │  Dispatch   FD.API.Router        │
│    │                                      │                                  │
│ ■  │                                      │  VÍNCULOS                        │
│ ○  │                                      │  3 papéis concedem este recurso  │
│ ○  │                                      │  7 usuários têm acesso           │
│ ○  │                                      │  1 especificação OpenAPI         │
│ ○  │                                      │                                  │
│ ○  │                                      │  [Edit]  [Disable]               │
└────┴──────────────────────────────────────┴──────────────────────────────────┘
```

**Glareshield, 44px, fixo.** Identidade da instância à esquerda, sinais vitais no centro, estado do modo seguro e usuário à direita. Permanece visível em toda tela, inclusive sobre camada flutuante. É onde o `SAFE MODE` vive, e por isso o estado nunca pode ser esquecido. Desarmado, o indicador muda para `LIVE` em `state-warning`, com fio de 2px na base da faixa atravessando a largura inteira.

**Rail, 56px, apenas ícones.** Seis destinos, exatamente os seis eixos do contest. Sem rótulo permanente: rótulo aparece em dica lateral e no primeiro uso. Seis ícones se aprendem em uma sessão, e o rail não pode competir com o conteúdo. Item ativo marcado por barra de 2px em `state-selected` na borda interna, não por preenchimento de fundo.

**Lista mais inspetor, sempre.** Detalhe **nunca** navega para outra página. Abre no inspetor à direita, mantendo a lista visível. Essa é a decisão que faz o grafo de entidades (RN-FD-13) parecer instantâneo: saltar entre entidades relacionadas troca o conteúdo do inspetor, não a tela. É também a diferença estrutural mais visível em relação ao portal nativo, que é página por objeto.

**Alinhamento.** Rótulo à esquerda, valor numérico à direita com numeral tabular, valor textual à esquerda. Coluna de rótulos do inspetor com largura fixa de 96px, de modo que todos os valores alinhem verticalmente em todos os domínios.

### 4.1 Abas de seção

Com cobertura integral da API oficial, dois domínios têm muitos tipos de entidade: Segurança reúne TLS, X.509, OAuth nos três papéis, wallet, criptografia, LDAP, MFT, auditoria e superserver; Sistema reúne instrumentos, processos, bancos, namespaces, dispositivos, licença, locks, sessões web, ECP, servidores de linguagem externa, DocDB e finalidades de acesso a arquivo.

Isso exige um nível de navegação, e ele é resolvido **sem tocar no rail**:

- Uma faixa de abas horizontal no cabeçalho de trabalho, abaixo do título, visível apenas nos domínios que têm mais de um tipo de entidade.
- Aba ativa marcada por fio de 2px em `state-selected` na borda inferior. Sem preenchimento de fundo, sem pílula, sem cápsula arredondada.
- A aba não é um destino novo: ela troca o conteúdo da lista, e o inspetor acompanha. O rail continua com seis itens, e essa é uma regra de projeto, não uma consequência.
- A ordem das abas é fixa e começa pela mais usada, não pela ordem alfabética nem pela ordem da especificação da API.
- A aba ativa entra na URL, para que uma seção específica seja compartilhável.
- ⚠️ Domínio com uma só entidade **não** exibe a faixa. Uma aba solitária é ruído.

A paleta continua sendo o caminho primário: digitar o nome da seção leva direto a ela, sem passar pelo rail nem pela faixa.

---

## 5. Momento assinatura 1: o cluster de instrumentos (UC08)

É onde a metáfora sai do texto e vira imagem. É o quadro do vídeo e a capa do artigo.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   CPU                    MEMORY                  DISK                       │
│                                                                             │
│    34                     61                      72                        │
│    %   ▁▂▃▅▃▂▁▂▃▄▅▆▅▃▂    %  ▃▃▄▄▄▅▅▅▅▆▆▆▆▆▆     %  ▅▅▅▅▅▅▅▆▆▆▆▆▆▆▆        │
│        60s                   60s                    IRISAPP 72% ▲           │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  PROCESSES  142 active                                    [Filter] [Sort]   │
│  PID     NAMESPACE   USER     ROUTINE            STATE      CPU    MEM      │
│  4128    IRISAPP     kadu     FD.API.Router      RUN       12.4%   84MB     │
│  3902    %SYS        _SYSTEM  %SYS.Task          RUN        4.1%   32MB     │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Especificação:**

- Leitura primária é o número, 40px, peso 500, numeral tabular, em `text-primary`. A cor do número muda para `state-caution` ou `state-warning` apenas ao cruzar limiar, e o ícone de estado aparece junto.
- Leitura secundária é a faixa temporal, 60 segundos, renderizada em **canvas**. Traço de 1.5px em `state-actual`, sem preenchimento, sem gradiente, sem eixo, sem grade, sem legenda. O contorno da série é a informação inteira.
- ⚠️ **Canvas, não SVG declarativo.** Com atualização a cada segundo e três a seis séries simultâneas, biblioteca declarativa baseada em SVG degrada de forma visível. Esta é a única decisão técnica desta especificação que, se ignorada, quebra o momento assinatura.
- A faixa desliza continuamente, sem transição de entrada a cada ponto. O movimento é o do tempo passando, e essa continuidade é o que faz a tela parecer viva em vez de atualizada.
- Limiar cruzado não pisca e não anima: muda de cor e ganha ícone. Alarme em interface de administração precisa ser percebido, não performado.
- Os três instrumentos compartilham a mesma geometria exata. Repetição rigorosa é o que produz a leitura de painel em vez de leitura de cartões.

---

## 6. Momento assinatura 2: dry-run atual contra comandado (UC10)

A revelação do dry-run é o único momento de movimento orquestrado do produto, e é onde a gramática de cor se paga.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Apply changes to role  %FlightDeck_Operator                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                        CURRENT              COMMANDED                       │
│  Description           Portal operator      Portal operator                 │
│  %Admin_Manage:U       granted              granted                         │
│  %Admin_Secure:U       granted              revoked                         │
│  %DB_IRISAPP:RW        granted              granted                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  IMPACT                                                                     │
│  4 users lose access to 2 protected objects                                 │
│  kadu · svc_batch · analyst_ro · integration                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  Type  %FlightDeck_Operator  to confirm    [__________]   [Cancel] [Apply]  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Especificação:**

- Duas colunas rotuladas `CURRENT` e `COMMANDED`. Valores atuais em `state-actual`, valores propostos em `state-commanded`. Linhas sem mudança ficam em `text-muted` nas duas colunas: o olho vai direto para o que muda, sem precisar procurar.
- **A orquestração:** a coluna `COMMANDED` entra deslizando 8px a partir da direita, em 160ms, e apenas as linhas alteradas escurecem o fundo em um passe de 240ms que decai. Sequência única, uma vez, ao abrir. Nada mais no produto se move assim, e é isso que torna o momento reconhecível.
- O bloco de impacto (RN-FD-11) fica abaixo do diff, não em aba separada. Se a operação afeta terceiros, essa informação precisa estar no mesmo campo visual da confirmação.
- O campo de confirmação por digitação (RN-FD-04) fica na mesma linha do botão. `Apply` permanece desabilitado até a correspondência exata, e o botão nunca muda de cor: ele sai de `text-muted` para o preenchimento acromático de ação primária.
- Palavra de ação idêntica do começo ao fim: o botão diz `Apply`, o aviso resultante diz `Applied`, a trilha de sessão registra `Applied`.

---

## 7. Anti-padrões

Lista de verificação de revisão. Qualquer item presente é defeito, não preferência.

- Cor decorativa, gradiente, ilustração colorida ou cor de marca em qualquer lugar.
- Cor semântica usada fora do seu significado, incluindo verde para "salvar" ou vermelho para "cancelar".
- Conteúdo picado em cartões arredondados idênticos com a mesma sombra.
- Sombra em superfície estrutural.
- Um único raio de borda aplicado a tudo.
- Rótulo em caixa alta, etiqueta sobrescrita acima de cada título, cadeia de metadados unida por ponto médio, seta anexada ao texto de botão ou link.
- Entrada com desvanecer e subir, elevação em passagem do cursor, qualquer transição acima de 200ms.
- Indicador de carregamento circular centralizado. Só esqueleto que preserva a forma do conteúdo.
- Numeral proporcional em coluna numérica ou em instrumento.
- Monoespaçado em rótulo de interface. Proporcional em conteúdo de log.
- Fonte carregada de CDN.
- Estado vazio que diz apenas que não há resultado, sem causa provável e sem próxima ação.
- Erro do IRIS substituído por texto genérico do portal.
- Contorno de foco suprimido em qualquer elemento.
- Emoji em qualquer parte da interface.

---

## 8. Piso de qualidade

Verificado antes da submissão, sem exceção:

- Contraste mínimo de 4.5 para texto e 3.0 para elemento de interface, medido nos tokens dos **dois temas**, não estimado. A verificação do tema claro usa as variantes semânticas escurecidas da Seção 3.1, nunca as do tema escuro.
- Troca de tema verificada em todas as telas, incluindo canvas dos instrumentos e camadas flutuantes.
- Toda tela operável apenas por teclado, com ordem de tabulação coerente com a ordem visual.
- Anel de foco visível em 100% dos elementos interativos.
- `prefers-reduced-motion` respeitado, incluindo o dry-run.
- Nenhuma informação transmitida apenas por cor.
- Funcional a partir de 1280px de largura. Abaixo disso, o inspetor vira camada sobreposta em vez de coluna.
- Numeral tabular presente em toda coluna numérica, verificado tela a tela.
- Tempo até primeira renderização útil abaixo de dois segundos em instância local.

---

## 9. Ordem de construção e o que cortar

**Dia 1, meia jornada.** Arquivo de tokens completo nos **dois temas** (cor, tipo, espaço, raio, elevação, movimento), alternador funcionando e fontes empacotadas. Nenhuma tela ainda. Fazer os dois temas agora custa cerca de uma hora a mais; fazer depois custa revisitar todo componente já escrito.

**Dia 2.** Concha: glareshield, rail, geometria lista mais inspetor, paleta. A concha fica pronta antes de qualquer domínio existir.

**Dias 3 a 5.** Primeiro domínio, que fecha o padrão replicável de tela: cabeçalho de lista, linha, inspetor, painel de vínculos, barra de ações. Junto, o diff do dry-run, com a orquestração completa. A partir daqui, nenhum domínio novo exige decisão de design.

**Dias 9 e 10.** Cluster de instrumentos em canvas. Segundo e último momento assinatura.

**Dia 13, duas horas.** Revisão contra a lista de anti-padrões da Seção 7, tela por tela. Não é polimento opcional: é a etapa que garante que a coerência sobreviveu à pressa.

**Se o prazo apertar, corte nesta ordem:**

1. Dicas de rótulo do rail. Rótulo permanente resolve, com prejuízo estético mínimo.
2. Animação de raio de impacto no grafo de permissões. A lista textual de afetados entrega a informação.
3. Densidade alternável. Fixe em alta.

**Contingência do tema claro.** Ele é entregável assumido e saiu da lista de cortes. Se ainda assim o cronograma romper, a degradação honesta não é remover o alternador: é entregar o tema claro com as telas de domínio e o dry-run verificados, aceitando imperfeição de contraste apenas nos instrumentos, que são o componente menos usado em ambiente claro. Remover o alternador depois de anunciado é pior do que nunca tê-lo prometido.

**Nunca corte, em nenhuma circunstância:** os tokens dos dois temas, o numeral tabular, o anel de foco, a orquestração do dry-run e o canvas do cluster de instrumentos. São os cinco itens que carregam a percepção de refino, e os cinco mais baratos de manter.

---

## 10. Relação com os demais documentos

| Documento | Relação |
|---|---|
| `02-PRD.md` | Define o que o produto faz. Este documento define como ele se parece e se comporta visualmente. Em divergência sobre aparência, este documento prevalece |
| `prototype.html` | Implementa as telas assinatura. **Em divergência entre este texto e o protótipo sobre a aparência de um componente já implementado nele, o protótipo prevalece** |
| Skill `flightdeck-design-system` | Versão condensada destas regras, carregada pelo agente ao escrever código de interface. Em divergência, este documento prevalece e a skill está desatualizada |
