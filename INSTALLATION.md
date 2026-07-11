# Instalação — LectureLens

Guia completo para rodar o projeto do zero, numa máquina onde ele nunca foi executado.
O caminho rápido é **um único comando** (`./bootstrap.sh`); o passo a passo manual e a
variante para Mac estão mais abaixo.

## ⚠️ Chaves de API — obrigatórias e próprias

**Quem for rodar o projeto precisa possuir chaves PRÓPRIAS de `GEMINI_API_KEY` e
`HUGGINGFACE_KEY`.** Elas não vêm no repositório (o `.env` não é versionado) e não podem
ser compartilhadas: as chamadas à API do Gemini são **cobradas na conta associada à
chave**.

| Chave | Onde obter | Para quê |
|---|---|---|
| `GEMINI_API_KEY` | [Google AI Studio](https://aistudio.google.com/apikey) | Tradução (C01), geração e embeddings (C02–C05) |
| `HUGGINGFACE_KEY` | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) | Download dos modelos locais de tradução (C01) |

## Pré-requisitos

- **Python 3.11+** e **git**
- ~5 GB de disco livres (dependências + ~2,4 GB de modelos locais do C01)
- GPU é **opcional**: o C01 detecta CUDA/MPS/CPU sozinho (na CPU, a tradução local só
  demora mais)

## Instalação com 1 comando

**Um único comando** clona, instala e roda tudo, do zero:

```bash
git clone git@github.com:efraxpc/llm-LectureLens.git && cd llm-LectureLens && ./bootstrap.sh
```

Não é preciso criar nem editar o `.env` à mão: na primeira vez, o próprio script cria o
`.env` a partir do `.env.example` e **pede as SUAS chaves** no terminal, uma de cada vez.
**Cole cada chave diretamente na linha do terminal quando ela for pedida** e aperte Enter;
a colagem fica oculta, nada é exibido, e o script grava a chave sozinho no `.env` da raiz
do projeto:

```text
[3/5] Preparando o arquivo .env ...
      Cole a chave do Google AI Studio (https://aistudio.google.com/apikey)
      e aperte Enter (a colagem não será exibida):
      ▉                     ← cole aqui a chave do Google e aperte Enter
      Cole o token do Hugging Face (https://huggingface.co/settings/tokens)
      e aperte Enter (a colagem não será exibida):
      ▉                     ← cole aqui o token do Hugging Face e aperte Enter
```

Depois da primeira vez, as chaves ficam salvas no `.env` e o script não as pede de novo.

O `bootstrap.sh` faz, em ordem:

1. **Cria o `.venv`** e instala `requirements.txt` (reutiliza se já existirem);
2. **Registra o kernel** do Jupyter `Python (llm_project)`;
3. **Prepara o `.env`**: cria-o a partir do modelo se faltar e pede no terminal cada
   chave ausente ou vazia (`GEMINI_API_KEY`, `HUGGINGFACE_KEY`), gravando-as no `.env`;
4. **Avisa** antes de executar: ~2,4 GB de download + ~20–40 min na primeira corrida;
5. **Executa os 5 notebooks em ordem de dependência** (C01 → C02 → C03 → C04 → C05) com
   `jupyter nbconvert --execute`, forçando o kernel registrado.

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

## Ordem de execução

O pipeline tem dependências entre etapas — respeite a ordem na primeira corrida:

| Ordem | Notebook | Gera |
|---|---|---|
| 1º | C01 | `data/processed/*_portugues.txt` e `*_espanhol*.txt` (~2,4 GB de download de modelos) |
| 2º | C02 | `relatorio_prompts_c02.csv` |
| 3º | C03 | `indice_faiss_c03.index` e `chunks_c03.json` (reaproveitados no C05) |
| 4º | C04 | — (usa uma aula processada como exemplo) |
| 5º | C05 | pipeline RAG completo |

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
