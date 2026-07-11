# LLM Project — Efrain INFNET

Projeto prático de Large Language Models desenvolvido para o curso INFNET.
O corpus são **transcrições reais de aulas** (em português), e o projeto percorre um
pipeline completo em cinco etapas: **traduzir** as aulas (C01), aplicar **técnicas de
prompting** (C02), **indexar e recuperar** com embeddings semânticos (C03), **justificar a
escolha de inferência** local/remota/privada (C04) e montar o **pipeline RAG** de ponta a
ponta (C05).

A partir do C02, toda a geração usa a **API do Gemini** (`google-genai`); o C01 compara
modelos locais de tradução com a API. Cada notebook é autocontido, escrito em português,
com prompts ao modelo em inglês.

## Estrutura do projeto

```
.
├── c01_modelos_llm.ipynb                                  # C01 — Leitura e tradução do corpus
├── c02_prompting.ipynb                                    # C02 — Técnicas de Prompting
├── c03_embeddings_semanticos_e_recuperacao_de_informacao.ipynb  # C03 — Embeddings e recuperação
├── c04_inferencia_local_remota_ou_privada.ipynb           # C04 — Inferência local, remota ou privada
├── c05_pipeline_RAG.ipynb                                 # C05 — Pipeline RAG
├── environment.yml                                        # Ambiente conda (recomendado no Mac)
├── requirements.txt                                       # Dependências pip (Linux/Windows)
├── CLAUDE.md
├── README.md
├── data/
│   ├── raw/                                               # Transcrições originais (WEBVTT, .vtt)
│   │   └── Sistemas_Cognitivos_com_LLMs_aula-*.vtt        # 8 aulas
│   └── processed/                                         # Gerado pelos notebooks (não versionado)
│       ├── *_portugues.txt                                # C01 — português limpo (corpus principal)
│       ├── *_espanhol.txt                                 # C01 — tradução NLLB (usada adiante)
│       ├── *_espanhol_helsinki.txt                        # C01 — tradução Helsinki (comparação)
│       ├── *_espanhol_gemini.txt                          # C01 — tradução Gemini (comparação)
│       ├── indice_faiss_c03.index                         # C03 — índice FAISS (reaproveitado no C05)
│       ├── chunks_c03.json                                # C03 — chunks + metadados + config de embeddings
│       └── relatorio_prompts_c02.csv                      # C02 — relatório de experimentos
└── .env                                                   # Não versionado — criar manualmente
```

## Notebooks

| Notebook | Tema | Modelos / API | Status |
|---|---|---|---|
| `c01_modelos_llm.ipynb` | Limpeza de transcrições WEBVTT e tradução PT→ES, comparando três métodos | Locais `nllb-200-distilled-600M` e `opus-mt-tc-big-itc-itc` + API `gemini-3.1-pro` | Criado |
| `c02_prompting.ipynb` | Cinco técnicas de prompting sobre duas tarefas (QA e sumarização), com saída JSON validada | API `gemini-3.5-flash` | Criado |
| `c03_embeddings_semanticos_e_recuperacao_de_informacao.ipynb` | Embeddings semânticos, indexação FAISS e análise da qualidade da recuperação | API `gemini-embedding-001` + `gemini-3.5-flash` + FAISS | Criado |
| `c04_inferencia_local_remota_ou_privada.ipynb` | Comparação local × remota × privada, critério por critério, justificando a API | API `gemini-3.5-flash` (+ torch para a opção local) | Criado |
| `c05_pipeline_RAG.ipynb` | Pipeline RAG completo: recuperação, prompt aumentado, resposta bilíngue, juiz de fidelidade, análise de riscos e controles | API `gemini-3.5-flash` + `gemini-embedding-001` + FAISS | Criado |

### Ordem de execução e dependência de dados

O pipeline tem dependências entre etapas:

- **C01** lê `data/raw/*.vtt` e gera `data/processed/*_portugues.txt` e `*_espanhol.txt`.
- **C02** e **C03** leem os arquivos processados por C01.
- **C03** gera os artefatos `indice_faiss_c03.index` e `chunks_c03.json`, que o **C05**
  reaproveita (não reindexa).

Como `data/processed/` **não vem versionado**, rode **C01 primeiro** e depois **C03** (ao
menos até a indexação) antes de C05. C04 é independente (só precisa de uma aula processada
como contexto de exemplo).

### Detalhe por notebook

**C01 — Leitura e tradução do corpus.** Limpa os `.vtt` (remove cabeçalho WEBVTT, números de
cue e timestamps, mantendo uma linha por cue) e traduz PT→ES por três caminhos, comparando
qualidade e custo: dois modelos locais (`facebook/nllb-200-distilled-600M`,
`Helsinki-NLP/opus-mt-tc-big-itc-itc`) e a API `gemini-3.1-pro`. Seções §1–§9 (NLLB,
tokenização, parâmetros de geração, Helsinki, API Gemini, comparação dos três, limitações,
qual encaixa melhor, conclusão). Roda em GPU (CUDA/MPS) ou CPU — detecta o dispositivo
sozinho.

**C02 — Técnicas de Prompting sobre o corpus traduzido.** Aplica cinco técnicas (zero-shot,
few-shot, Chain-of-Thought, meta-prompting, iteração v1→v2→v3) a duas tarefas de NLP —
Question Answering e sumarização por tópico — com saída em JSON validada (parsing, validador
e retentativa). Seções §1–§5 (QA, sumarização, síntese final, relatório de experimentos,
conclusão).

**C03 — Embeddings semânticos e recuperação de informação.** Divide o corpus em chunks com
sobreposição e metadados, indexa com `gemini-embedding-001` (768 dimensões, task types
assimétricos) num FAISS `IndexFlatIP`, e avalia a qualidade da recuperação com consultas de
teste (incluindo expansão de consulta com HyDE e uma consulta adversarial). Seções §1–§6.

**C04 — Inferência local, remota ou privada.** Compara três formas de rodar um modelo —
local (Ollama/Hugging Face), remota (API paga por token) e privada (servidor próprio) —
reunindo evidências critério por critério (privacidade, custo, latência, disponibilidade,
controle, integração, hardware, internet, exposição de dados) e justificando a API do Gemini
Flash. Seções §1–§5.

**C05 — Pipeline RAG.** Monta o RAG completo sobre os artefatos do C03: recupera os trechos
top-k, monta o prompt aumentado com regras de grounding, gera a resposta nos dois idiomas
citando as fontes, e avalia a fidelidade com um juiz LLM. Fecha com uma bateria de análise:
pontos de falha, limites de contexto, guardrails contra prompt injection, risco de vazamento
e controles de segurança propostos. Seções §1–§14.

## Configuração

### Rodar em Mac (Apple Silicon / chip M) — recomendado (conda)

No Mac com chip M, a forma mais portável é um ambiente **conda** com o `environment.yml`
deste repositório, em vez de `pip` solto: `faiss`, `pytorch` e `sentencepiece` têm build
nativo `osx-arm64` no conda-forge, o que evita wheels que faltam e o problema de instalar
o torch duas vezes.

```bash
# 1. Instalar o miniforge (conda nativo arm64), se ainda não tiver
brew install --cask miniforge      # ou baixe de https://conda-forge.org/download/

# 2. Criar e ativar o ambiente a partir do environment.yml
conda env create -f environment.yml
conda activate llm_project

# 3. Registrar o kernel do Jupyter
python -m ipykernel install --user --name=llm_project --display-name "Python (llm_project)"

# 4. Abrir os notebooks e selecionar o kernel "Python (llm_project)"
jupyter lab
```

Crie também o arquivo `.env` na raiz (ver a seção de variáveis de ambiente abaixo). As
chaves realmente usadas hoje são `GEMINI_API_KEY` (C01–C05) e o token do Hugging Face para
os modelos locais do C01.

**Notas de portabilidade no Mac:**

- **Dispositivo**: o C01 (modelos locais de tradução) detecta o dispositivo sozinho e roda
  em **MPS** (a GPU do Apple Silicon) sem nenhuma configuração; nada de CUDA. Os notebooks
  **C02–C05 são só chamadas de API** (Gemini + FAISS), então rodam em qualquer máquina.
- **Dados**: a pasta `data/processed/` **não vem versionada** no repositório. Rode o
  **C01** primeiro para gerá-la a partir de `data/raw/`; os notebooks C02–C05 leem de
  `data/processed/*_portugues.txt`. Se você quiser só o pipeline de API (C02–C05) sem
  instalar o torch, a alternativa é versionar `data/processed/` e pular o C01.
- **Ollama** (opção de inferência local discutida no C04) é **opcional**: instale com
  `brew install ollama` apenas se for executar essa comparação.

O passo a passo genérico com `venv`/`pip` abaixo continua válido para Linux/Windows.

### 1. Ambiente virtual

```bash
python -m venv .venv
source .venv/bin/activate        # Linux/macOS
.venv\Scripts\activate           # Windows
pip install -r requirements.txt
```

### 2. Variáveis de ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
GEMINI_API_KEY=sua_chave_aqui      # principal — usada em C01–C05 (Google AI Studio)
HUGGINGFACE_KEY=sua_chave_aqui     # token do HF Hub, lido via huggingface_hub.login() no C01
ANTHROPIC_API_KEY=sua_chave_aqui   # opcional — nas dependências, mas sem uso nos notebooks atuais
OPENAI_API_KEY=sua_chave_aqui      # opcional
```

### 3. Inferência local (opcional — somente C04)

```bash
# Instalar Ollama: https://ollama.com
ollama serve
ollama pull llama3.2
```

### 4. Registrar o kernel do Jupyter

```bash
python -m ipykernel install --user --name=llm_project --display-name "Python (llm_project)"
```

Isso garante que os notebooks rodem com o ambiente do projeto, e não com um Python global.

### 5. Executar os notebooks

```bash
jupyter lab
```

Ao abrir cada notebook, selecione o kernel **"Python (llm_project)"**.

## Dados

**Transcrições de aula** (`data/raw/`): 8 arquivos WEBVTT (`.vtt`) das aulas da disciplina.
São a entrada do C01 e a única fonte hand-authored do projeto.

**Corpus processado** (`data/processed/`, gerado pelos notebooks, **não versionado**):

- `*_portugues.txt` — transcrição limpa em português, sem timestamps nem índices (corpus
  principal de C02 a C05).
- `*_espanhol.txt` — tradução PT→ES pelo NLLB, usada adiante no pipeline.
- `*_espanhol_helsinki.txt` e `*_espanhol_gemini.txt` — traduções pelo Helsinki e pela API
  do Gemini, geradas só para a comparação de qualidade do C01.
- `indice_faiss_c03.index` e `chunks_c03.json` — índice FAISS e metadados dos chunks,
  gerados pelo C03 e reaproveitados pelo C05.
- `relatorio_prompts_c02.csv` — relatório de experimentos do C02.

## Modelos utilizados

Toda a geração usa a família **Gemini** via `google-genai`; o C01 é o único que também roda
modelos locais (para comparar com a API).

| Modelo | Tipo | Notebook / uso |
|---|---|---|
| `facebook/nllb-200-distilled-600M` | Local, encoder-decoder | C01 — tradução PT→ES (a usada adiante) |
| `Helsinki-NLP/opus-mt-tc-big-itc-itc` | Local, encoder-decoder | C01 — 2º modelo local (comparação) |
| `gemini-3.1-pro` (Preview) | API remota | C01 — tradução via API (melhor qualidade, comparação) |
| `gemini-embedding-001` | API — embeddings (768d) | C03, C05 — indexação e busca vetorial |
| `gemini-3.5-flash` | API remota | C02, C03, C04, C05 — geração, prompting e RAG |

> `anthropic` e `openai` ficam nas dependências, mas **nenhum notebook atual os usa** — a
> escolha do projeto convergiu para a família Gemini.

## Ambiente e dependências

- **Mac (Apple Silicon)**: use `environment.yml` (conda-forge) — ver a seção de configuração.
- **Linux/Windows**: use `requirements.txt` (pip).

Principais bibliotecas:

```
google-genai>=1.0.0        # API do Gemini (geração e embeddings) — C01–C05
faiss-cpu>=1.8.0           # busca vetorial — C03, C05
transformers>=4.45.0       # modelos locais de tradução — C01
torch>=2.4.0               # backend dos modelos locais (CUDA/MPS/CPU) — C01, C04
sentencepiece>=0.2.0       # tokenização dos modelos de tradução — C01
sentence-transformers>=3.0.0
python-dotenv>=1.0.0
numpy>=1.26.0 · pandas>=2.2.0
jupyter>=1.1.0 · ipykernel>=6.29.0
```

## Notas e problemas conhecidos

- **Determinismo é melhor esforço na API**: os notebooks usam `temperature=0` e `seed=42`,
  mas, segundo a documentação do Google, a reprodutibilidade exata não é garantida entre
  execuções (diferente de um modelo local). As perguntas de teste servem como teste de
  regressão do provedor.
- **`thinking` desligado no Flash**: em C03–C05 usa-se `thinking_budget=0` (ou baixo), porque
  o *thinking* oculto consumia parte imprevisível do `max_output_tokens` e cortava saídas
  curtas — lição registrada no C03.
- **Dependência de dados**: rode **C01** antes de C02/C03, e **C03** (até a indexação) antes
  de C05, pois `data/processed/` não é versionado.
- **Deprecação de modelo**: o modelo de embeddings `text-embedding-004` foi descontinuado
  durante o projeto e substituído por `gemini-embedding-001`; trocar o modelo de embeddings
  exige reindexar (custo de centavos nesta escala).

## Autor

Efrain Colmenares — INFNET 2026
