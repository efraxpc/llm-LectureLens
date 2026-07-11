# Relatório do Projeto — LectureLens

**Aluno:** Efrain Colmenares
**Curso:** INFNET — 2026
**Disciplina:** Sistemas Cognitivos com LLMs

## O projeto: LectureLens

**LectureLens** é um assistente que coloca uma lente sobre as transcrições das aulas: ele
traduz o conteúdo do português para o espanhol e deixa o aluno hispanofalante **fazer
perguntas em espanhol sobre o que foi dito em aula**, recebendo respostas fundamentadas nos
trechos reais das transcrições, com a fonte citada (aula e faixa de linhas) e um juiz
automático que confere a fidelidade de cada resposta.

O nome resume a proposta: como uma lente, o sistema **não cria conteúdo novo — ele deixa
nítido o que já está nas aulas**. A transcrição chega com ruído (gírias, erros do
reconhecimento de voz, nomes trocados) e em outro idioma; o pipeline limpa, traduz, indexa
e recupera, para que o aluno enxergue o conteúdo com clareza e possa confiar no que lê,
porque cada afirmação aponta para o lugar exato de onde saiu.

Por trás da lente, o projeto é um pipeline completo de LLMs construído em cinco etapas:
tradução do corpus (C01), técnicas de prompting (C02), embeddings e recuperação semântica
(C03), justificativa da inferência remota (C04) e o pipeline RAG de ponta a ponta, com
análise de riscos e controles de segurança (C05).

> *Em inglês, para portfólio: **LectureLens** — cross-lingual RAG pipeline that lets
> Spanish-speaking students query Portuguese lecture transcripts, with grounded,
> source-cited answers and LLM-judged faithfulness.*

---

## 1. Introdução — o problema e a ideia

A ideia deste projeto nasceu de um problema que eu mesmo conheço de perto: um estudante
hispanofalante morando num país lusófono precisa entender aulas dadas em português — e as
aulas reais têm gírias, informalidade e erros de transcrição que uma tradução literal não
resolve.

O projeto constrói, passo a passo, a base de um produto (um SaaS) que resolveria isso:
traduzir as transcrições das aulas para o espanhol e deixar o aluno **fazer perguntas em
espanhol sobre o conteúdo**, recebendo respostas fundamentadas no que foi realmente dito em
aula, com a fonte citada.

Para chegar lá, dividi o trabalho em cinco notebooks, cada um cobrindo uma etapa da
disciplina:

| Etapa | Notebook | O que faz |
|---|---|---|
| C01 | `c01_modelos_llm.ipynb` | Limpa e traduz as transcrições (PT→ES), comparando 3 métodos |
| C02 | `c02_prompting.ipynb` | Testa 5 técnicas de prompting em 2 tarefas de NLP |
| C03 | `c03_embeddings_semanticos_e_recuperacao_de_informacao.ipynb` | Indexa o corpus com embeddings e avalia a busca semântica |
| C04 | `c04_inferencia_local_remota_ou_privada.ipynb` | Compara inferência local, remota e privada, e justifica a escolha |
| C05 | `c05_pipeline_RAG.ipynb` | Monta o pipeline RAG completo e o testa até os limites |

Uma decisão que atravessa o projeto inteiro: **medir em vez de supor**. Sempre que afirmo
algo neste relatório (um score, um custo, uma taxa de erro), o número veio de uma célula
executada de verdade contra os dados ou contra a API.

## 2. Os dados

O corpus são **8 transcrições reais de aulas** da disciplina, no formato WEBVTT (`.vtt`),
em português. São fala espontânea transcrita automaticamente — o que trouxe problemas
interessantes de verdade: nomes de pessoas virando palavras comuns, "Hugging Face" escrito
como "Ruginface", "CUDA" como "cuida". Esses defeitos acabaram virando parte do estudo.

O C01 limpa esses arquivos (remove timestamps e números de cue, mantendo uma linha por
fala) e gera, para cada aula, o texto limpo em português e a tradução em espanhol — que
alimentam todas as etapas seguintes.

## 3. Etapa por etapa

### C01 — Tradução do corpus (três caminhos comparados)

Traduzi a mesma aula por três caminhos: dois modelos locais especializados em tradução
(`facebook/nllb-200-distilled-600M` e `Helsinki-NLP/opus-mt-tc-big-itc-itc`) e a API do
**Gemini 3.1 Pro**. Depois comparei os três, palavra por palavra.

O que eu descobri (medido, não achismo):

- Nos trechos fáceis, os três acertam. Mas mesmo nos trechos em que os modelos locais quase
  empatam com o Gemini, o Gemini ainda corrige o que eles erram: a gíria **"beleza"** virou
  *"genial"* (correto) no Gemini e *"belleza"* (literal, errado) nos dois locais.
- O problema mais sério dos locais são os **nomes próprios**: o NLLB perdeu ou alterou o
  nome de quem fala em **cerca de um terço** das linhas com nome (chegou a traduzir
  `fabricio.gouveia` como `Fábrica.Guveia`); o Helsinki erra bem menos (menos de 5%), mas
  por grafia.
- Custo: um servidor com GPU para rodar modelo local custaria uns **US$384 por mês, fixo**;
  a API cobra por uso e uma aula inteira sai por **centavos**. Traduzir uma aula (~700
  linhas) levou ~2 minutos numa GPU local.

Lição da etapa: **nenhum modelo local pequeno fecha a diferença de qualidade** nas coisas
que mais importam para o nosso caso (gíria, pragmática, nomes) — e a tradução é o exemplo
perfeito de por que a arquitetura encoder-decoder existe.

### C02 — Técnicas de prompting (5 técnicas × 2 tarefas)

Rodei as mesmas cinco técnicas — zero-shot, few-shot, Chain-of-Thought, meta-prompting e
iteração de prompts v1→v2→v3 — contra duas tarefas sobre a mesma aula: **Question
Answering** e **sumarização por tópico**, nos dois idiomas, sempre com saída em JSON
validada por código (parsing + validador + retentativa quando o JSON vem quebrado).

O que aprendi:

- **Não existe técnica melhor em geral — existe técnica melhor para cada tarefa.** Para QA,
  o que mais ajudou foi fazer o modelo **raciocinar com evidência** (Chain-of-Thought + um
  campo `evidencia` no JSON): dá para auditar de onde saiu cada afirmação. Para
  sumarização, o que funcionou foi **especificar escopo e estrutura** (iteração de prompts
  ou meta-prompting + esquema JSON).
- O few-shot, que é decisivo em tarefas de critério fixo, aqui foi coadjuvante: mudou o
  estilo, não o acerto, e custou mais tokens.
- A única "técnica" que valeu para tudo: **saída estruturada com validação e retentativa**.
  Esse mesmo mecanismo é reaproveitado depois no juiz do C05.

Todo o notebook rodou na API do Gemini Flash com custo real medido e registrado num
relatório de experimentos (CSV) — na casa dos **centavos**.

### C03 — Embeddings semânticos e recuperação

Cortei o corpus em chunks de 5 linhas com sobreposição de 2 (para uma pergunta e sua
resposta não ficarem separadas na borda), gerei embeddings com `gemini-embedding-001` (768
dimensões, com task types diferentes para documento e consulta) e indexei tudo num FAISS.
Cada chunk carrega aula e linhas de origem — rastreabilidade que aparece depois nas
respostas do RAG.

Testei a busca com consultas pensadas para forçar situações diferentes:

- **Consultas boas** voltaram com scores de **~0,65 a 0,74**, trazendo os trechos certos —
  inclusive quando a pergunta usava o termo correto ("Hugging Face") e o transcript tinha o
  termo errado ("Ruginface"): a busca por significado tolerou o erro de grafia.
- Uma **consulta adversarial** (doença renal em gatos — nada a ver com as aulas) caiu para
  **~0,53**. Isso é ótimo: como o índice sempre devolve k resultados, o score baixo é o
  único sinal de "não há resposta boa no corpus".
- A expansão de consulta (**HyDE** — reescrever a pergunta como se fosse uma fala de aula)
  subiu um pouco os scores nos casos bons (ex.: 0,72 → 0,74).

Ao final, o índice e os chunks ficam **salvos em disco** (`indice_faiss_c03.index`,
`chunks_c03.json`) — o C05 carrega esses artefatos prontos em vez de reindexar e pagar de
novo.

### C04 — Inferência local, remota ou privada

Antes de montar o produto final, parei para justificar a decisão de infraestrutura:
comparei rodar o modelo **local** (Ollama / Hugging Face), **remoto** (API paga por token)
ou **privado** (servidor próprio com GPU), critério por critério: privacidade, custo,
latência, disponibilidade, controle, integração, hardware, internet e exposição de dados.

A conclusão, sempre na régua de um SaaS pequeno começando:

- **Custo decide quase sozinho**: pagar por token (centavos por pergunta) contra US$384–400
  por mês fixos de um servidor com GPU, mesmo parado.
- O preço honesto da API é a **privacidade** (o texto viaja para o provedor — aceitável
  aqui porque são transcrições de aula, sem dados sensíveis) e a **dependência de
  terceiros** (a reprodutibilidade com `seed=42` é melhor esforço, não garantia).
- O que importa continua nosso: prompts, validação e retentativas. E o limite de contexto,
  medido ao vivo na API, é de ~1 milhão de tokens de entrada — folga de sobra.

### C05 — O pipeline RAG completo (e os seus limites)

O C05 junta tudo: carrega o índice do C03, recupera os 3 trechos mais próximos da pergunta,
monta um **prompt aumentado** com regras (responder só com o contexto, não inventar, usar
um fallback fixo quando a resposta não está lá, citar as fontes com aula e linhas), gera a
resposta **em espanhol e em português**, e um **juiz LLM** verifica se cada afirmação da
resposta tem suporte nos trechos — inclusive detectando uma resposta adulterada de
propósito, que era o teste de que o juiz funciona.

Depois de mostrar o pipeline funcionando (perguntas de aluno, sessão reproduzível com
sorteio de semente fixa, comparação com/sem contexto, casos de alucinação provocados), levei
o notebook para a parte que mais me ensinou: **onde ele quebra**.

- **Pontos de falha mais prováveis**: implementei um limiar de confiança no score (0,65, o
  piso da faixa boa). Ele barra o que claramente foge do corpus (impostos: 0,616; gatos:
  0,530) sem gastar um token de geração — mas descobri medindo que uma pergunta **tangente**
  (fine-tuning com LoRA, tema citado mas nunca ensinado) pontua **0,663, dentro da faixa
  boa**, e passa. O score mede semelhança de assunto, não profundidade de cobertura. A
  defesa é o conjunto: limiar + fallback + juiz.
- **Limitações de contexto**: medi com `count_tokens` que o prompt padrão (k=3) usa **741
  tokens (0,07% do limite)** e que o corpus inteiro colado no prompt usaria **164.440
  (15,7%)** — ou seja, caberia! Mas custaria ~222× mais por pergunta, perderia a
  rastreabilidade e sofreria do "lost in the middle". O motivo de recuperar em vez de colar
  tudo não é o limite: é custo, precisão e fonte.
- **Cobertura do k=3**: para uma pergunta de agregação ("que temas o curso cobre?"), k=3
  trouxe evidência de **1 aula só**; k=12 cobriu **7 de 8**. E o detalhe perigoso: a
  resposta incompleta continua *fiel*, então o juiz não a acusa — fidelidade não é
  completude.
- **Segurança**: injetei de propósito um trecho malicioso ("IGNORE ALL PREVIOUS
  INSTRUCTIONS...") e um trecho com dados pessoais falsos (e-mail e telefone). O detector de
  padrões barrou a injeção; a regra do prompt resistiu mesmo quando deixei o ataque passar
  (medido, não assumido); e a redação de PII substituiu o e-mail e o telefone por
  `[REDIGIDO]` **antes** de o texto sair para o provedor. Fechei com um registro de
  **controles de segurança propostos** — 7 técnicos (verificados por código como presentes
  no notebook) e 5 operacionais (para quando o protótipo virar produto).

## 4. Dificuldades e lições aprendidas

Estas foram as pedras no caminho — e o que cada uma me ensinou:

1. **Um modelo foi descontinuado no meio do projeto.** O `text-embedding-004` deixou de
   existir e tive que migrar para o `gemini-embedding-001` e reindexar. Lição: o nome do
   modelo tem que viajar junto com os artefatos (ficou gravado no `chunks_c03.json`), e o
   custo de reindexar (centavos) precisa estar previsto.
2. **O "thinking" oculto do modelo cortava minhas respostas.** No Flash, o raciocínio
   interno consumia parte imprevisível do `max_output_tokens` e truncava saídas curtas.
   Solução: `thinking_budget=0` nas tarefas que não precisam dele.
3. **Determinismo na API é promessa, não contrato.** Mesmo com `temperature=0` e `seed=42`,
   a documentação avisa que é melhor esforço. Por isso separei o que eu posso garantir (o
   sorteio das perguntas da sessão, com semente do Python) do que o provedor promete (a
   redação exata).
4. **JSON de modelo quebra.** De vez em quando a saída vem malformada. A resposta de
   engenharia foi um `gerar_json` com parsing, validador de esquema e retentativa enviando o
   erro de volta ao modelo — usado igual em C02, C03 e C05.
5. **Os erros do corpus são parte do problema real.** "Ruginface" e "cuida" não eram ruído
   para limpar e esquecer: viraram testes de robustez da busca semântica e um ponto de
   falha documentado do RAG.

## 5. Conclusão

O projeto saiu do arquivo `.vtt` cru e chegou a um pipeline RAG funcionando de ponta a
ponta: o aluno pergunta em espanhol, o sistema recupera os trechos certos das aulas em
português, responde nos dois idiomas citando aula e linhas, e um juiz confere a fidelidade.

As três conclusões que eu levo:

1. **A recuperação é o teto da resposta.** Se o trecho certo não entra no top-k, não há
   modelo bom que conserte. Por isso tanto cuidado com chunking, task types, scores e
   consultas adversariais.
2. **Qualidade se mede, não se assume.** As decisões do projeto (qual tradutor, qual
   técnica de prompting, qual modelo de geração, qual k) saíram de comparações executadas,
   com números — e mais de uma vez o número me surpreendeu (a pergunta tangente passando o
   limiar, por exemplo).
3. **Para um produto pequeno, a API vence.** Centavos por pergunta, sem servidor, com o
   controle que importa (prompts, validação, juiz) do nosso lado — e com os riscos mapeados
   e controles propostos para o dia em que o protótipo virar produto de verdade.

## 6. Como executar o projeto

O passo a passo completo está no `README.md` (inclusive a rota recomendada para Mac com
chip M, via conda e `environment.yml`). Em resumo: criar o ambiente, configurar o `.env`
com a `GEMINI_API_KEY`, rodar o **C01** (gera `data/processed/`), depois o **C03** até a
indexação, e então qualquer um dos demais notebooks, sempre com o kernel
**"Python (llm_project)"**.
