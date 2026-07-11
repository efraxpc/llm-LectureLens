# Instalação — LectureLens

Guia completo para rodar o projeto do zero, numa máquina onde ele nunca foi executado.
O caminho rápido é **um único comando** (`./bootstrap.sh`); o passo a passo manual e a
variante para Mac estão mais abaixo.

## ⚠️ Chaves de API — obrigatórias e próprias

**Quem for rodar o projeto precisa possuir chaves PRÓPRIAS de `GEMINI_API_KEY` e
`HUGGINGFACE_KEY`.** Elas não vêm no repositório (o `.env` não é versionado) e não podem
ser compartilhadas: as chamadas à API do Gemini são **cobradas na conta associada à
chave** — a primeira execução completa gasta ~US$ 2,0–2,5, quase tudo nas 8 traduções
com o Gemini Pro do C01.

| Chave | Onde obter | Para quê |
|---|---|---|
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/apikey) | Tradução (C01), geração e embeddings (C02–C05) |
| `HUGGINGFACE_KEY` | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) | Download dos modelos locais de tradução (C01) |

As opcionais `ANTHROPIC_API_KEY` e `OPENAI_API_KEY` estão nas dependências, mas nenhum
notebook atual as usa.

## Pré-requisitos

- **Python 3.11+** e **git**
- ~5 GB de disco livres (dependências + ~2,4 GB de modelos locais do C01)
- GPU é **opcional**: o C01 detecta CUDA/MPS/CPU sozinho (na CPU, a tradução local só
  demora mais)

## Instalação com 1 comando

```bash
git clone git@github.com:efraxpc/llm-LectureLens.git
cd llm-LectureLens
cp .env.example .env      # e preencha com as SUAS chaves
./bootstrap.sh
```

O `bootstrap.sh` faz, em ordem:

1. **Cria o `.venv`** e instala `requirements.txt` (reutiliza se já existirem);
2. **Registra o kernel** do Jupyter `Python (llm_project)`;
3. **Verifica o `.env`**: aborta com mensagem clara se `GEMINI_API_KEY` ou
   `HUGGINGFACE_KEY` estiverem ausentes ou vazias;
4. **Avisa o custo** antes de gastar: ~2,4 GB de download + ~US$ 2,0–2,5 de API +
   ~20–40 min na primeira corrida;
5. **Executa os 5 notebooks em ordem de dependência** (C01 → C02 → C03 → C04 → C05) com
   `jupyter nbconvert --execute`, forçando o kernel registrado.

**Reanudação inteligente**: se `data/processed/` já tiver as 8 aulas processadas, o C01
é **pulado** (é a etapa cara — as traduções pagas). Para reexecutá-lo mesmo assim:

```bash
FORCE_C01=1 ./bootstrap.sh
```

Para só preparar o ambiente **sem executar nada** (nenhum gasto de API):

```bash
SOLO_PREPARAR=1 ./bootstrap.sh
```

## Instalação manual (passo a passo)

Se preferir controlar cada etapa em vez do script:

### 1. Ambiente virtual

```bash
python -m venv .venv
source .venv/bin/activate        # Linux/macOS
.venv\Scripts\activate           # Windows
pip install -r requirements.txt
```

### 2. Variáveis de ambiente

Crie o `.env` na raiz a partir do modelo e preencha com as **suas** chaves:

```bash
cp .env.example .env
```

```env
GEMINI_API_KEY=sua_chave_aqui      # obrigatória — usada em C01–C05
HUGGINGFACE_KEY=sua_chave_aqui     # obrigatória — modelos locais do C01
```

### 3. Registrar o kernel do Jupyter

```bash
python -m ipykernel install --user --name=llm_project --display-name "Python (llm_project)"
```

Isso garante que os notebooks rodem com o ambiente do projeto, e não com um Python global.

### 4. Executar os notebooks

```bash
jupyter lab
```

Ao abrir cada notebook, selecione o kernel **"Python (llm_project)"** e execute na ordem
de dependências (abaixo).

## Ordem de execução e custos

O pipeline tem dependências entre etapas — respeite a ordem na primeira corrida:

| Ordem | Notebook | Gera | Custo aproximado |
|---|---|---|---|
| 1º | C01 | `data/processed/*_portugues.txt` e `*_espanhol*.txt` | ~US$ 2,0–2,5 (8 traduções Gemini Pro) + ~2,4 GB de download |
| 2º | C02 | `relatorio_prompts_c02.csv` | centavos |
| 3º | C03 | `indice_faiss_c03.index` e `chunks_c03.json` (reaproveitados no C05) | centavos |
| 4º | C04 | — (usa uma aula processada como exemplo) | centavos |
| 5º | C05 | pipeline RAG completo + custos medidos | centavos |

Como `data/processed/` **não vem versionado**, o C01 precisa rodar antes de C02/C03, e o
C03 (ao menos até a indexação) antes do C05.

## Mac (Apple Silicon / chip M) — variante com conda

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

Crie também o `.env` (seção de chaves acima). Notas de portabilidade:

- **Dispositivo**: o C01 roda em **MPS** (a GPU do Apple Silicon) sem nenhuma
  configuração; nada de CUDA. Os notebooks C02–C05 são só chamadas de API (Gemini +
  FAISS), então rodam em qualquer máquina.
- Com conda, o `bootstrap.sh` não se aplica (ele usa `venv`/`pip`); siga a ordem de
  execução da tabela acima manualmente.

## Ollama (opcional — somente C04)

A opção de inferência local discutida no C04 usa Ollama. Instale apenas se for executar
essa comparação:

```bash
# https://ollama.com  (ou: brew install ollama, no Mac)
ollama serve
ollama pull llama3.2
```
