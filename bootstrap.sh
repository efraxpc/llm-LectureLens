#!/usr/bin/env bash
# bootstrap.sh — instala e roda o projeto inteiro do zero, com um único comando.
#
# Uso:
#   ./bootstrap.sh                  # instala tudo e executa os 5 notebooks em ordem
#   SOLO_PREPARAR=1 ./bootstrap.sh  # só prepara o ambiente (venv, kernel, .env), sem rodar
#   FORCE_C01=1 ./bootstrap.sh      # força reexecutar o C01 mesmo com data/processed pronto
#
# Pré-requisito: arquivo .env na raiz com chaves PRÓPRIAS (ver INSTALLATION.md):
#   GEMINI_API_KEY e HUGGINGFACE_KEY
set -euo pipefail
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"
VENV=".venv"
KERNEL="llm_project"
NOTEBOOKS=(
  c01_modelos_llm.ipynb
  c02_prompting.ipynb
  c03_embeddings_semanticos_e_recuperacao_de_informacao.ipynb
  c04_inferencia_local_remota_ou_privada.ipynb
  c05_pipeline_RAG.ipynb
)

echo "══════════════════════════════════════════════════════════"
echo " LectureLens — bootstrap"
echo "══════════════════════════════════════════════════════════"

# ── 1. Ambiente virtual e dependências ─────────────────────────────────────────
if [ ! -x "$VENV/bin/python" ]; then
  echo "[1/5] Criando ambiente virtual em $VENV ..."
  "$PYTHON" -m venv "$VENV"
else
  echo "[1/5] Ambiente virtual $VENV já existe — reutilizando."
fi
echo "      Instalando dependências de requirements.txt (pode demorar na 1ª vez) ..."
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r requirements.txt

# ── 2. Kernel do Jupyter ───────────────────────────────────────────────────────
echo "[2/5] Registrando o kernel do Jupyter ($KERNEL) ..."
"$VENV/bin/python" -m ipykernel install --user --name="$KERNEL" \
  --display-name "Python (llm_project)" >/dev/null

# ── 3. Arquivo .env com as chaves (devem ser SUAS — ver INSTALLATION.md) ──────
# Cria o .env sozinho e pede as chaves que faltarem, para bastar UM comando.
echo "[3/5] Preparando o arquivo .env ..."
if [ ! -f .env ]; then
  echo "      .env não existe — criando a partir de .env.example."
  cp .env.example .env
fi

# Rótulo amigável de cada chave: o que colar e onde obter (mostrado no console).
rotulo_chave() {  # $1 = nome da variável
  case "$1" in
    GEMINI_API_KEY)   echo "a chave do Google AI Studio (https://aistudio.google.com/apikey)" ;;
    HUGGINGFACE_KEY)  echo "o token do Hugging Face (https://huggingface.co/settings/tokens)" ;;
    *)                echo "a chave $1" ;;
  esac
}

definir_chave() {  # $1 = nome da chave; grava/atualiza a linha no .env
  local nome="$1" valor tmp
  read -rs valor
  echo ""
  if [ -z "$valor" ]; then
    echo "ERRO: ${nome} não pode ficar vazia — instruções em INSTALLATION.md."
    exit 1
  fi
  tmp="$(mktemp)"
  grep -v "^${nome}=" .env > "$tmp" || true
  printf '%s=%s\n' "$nome" "$valor" >> "$tmp"
  mv "$tmp" .env
}

for CHAVE in GEMINI_API_KEY HUGGINGFACE_KEY; do
  if ! grep -Eq "^${CHAVE}=.+" .env; then
    if [ -t 0 ]; then
      echo "      Cole $(rotulo_chave "$CHAVE")"
      echo "      e aperte Enter (a colagem não será exibida):"
      definir_chave "$CHAVE"
    else
      echo ""
      echo "ERRO: ${CHAVE} ausente ou vazia no .env, e não há terminal interativo"
      echo "para pedi-la. Preencha o .env à mão — instruções em INSTALLATION.md."
      exit 1
    fi
  fi
done
echo "      .env OK (GEMINI_API_KEY e HUGGINGFACE_KEY presentes)."

if [ "${SOLO_PREPARAR:-0}" = "1" ]; then
  echo "[4/5] SOLO_PREPARAR=1 — ambiente pronto, notebooks NÃO executados."
  echo "[5/5] Para rodar tudo: ./bootstrap.sh"
  exit 0
fi

# ── 4. Aviso de custo e tempo ──────────────────────────────────────────────────
echo "[4/5] Atenção — a primeira execução completa:"
echo "      • baixa ~2,4 GB de modelos locais de tradução (C01);"
echo "      • gasta ~US\$ 2,0–2,5 na API do Gemini (8 traduções com o Pro em C01"
echo "        + centavos em C02–C05), cobrados na conta da SUA chave;"
echo "      • leva ~20–40 min, dependendo de GPU e conexão."

# ── 5. Execução dos notebooks em ordem de dependência ─────────────────────────
echo "[5/5] Executando os notebooks ..."
executar() {
  echo "      ▶ $1"
  "$VENV/bin/jupyter" nbconvert --to notebook --execute --inplace \
    --ExecutePreprocessor.kernel_name="$KERNEL" \
    --ExecutePreprocessor.timeout=3600 "$1"
}

N_PROCESSADOS=$(ls data/processed/*_portugues.txt 2>/dev/null | wc -l)
if [ "${FORCE_C01:-0}" != "1" ] && [ "$N_PROCESSADOS" -ge 8 ]; then
  echo "      ▷ ${NOTEBOOKS[0]} PULADO — data/processed já tem $N_PROCESSADOS aulas"
  echo "        processadas (use FORCE_C01=1 para reexecutar e pagar as traduções)."
else
  executar "${NOTEBOOKS[0]}"
fi
for NB in "${NOTEBOOKS[@]:1}"; do
  executar "$NB"
done

echo "══════════════════════════════════════════════════════════"
echo " Pronto: os 5 notebooks foram executados com sucesso."
echo " Abra-os com: $VENV/bin/jupyter lab"
echo "══════════════════════════════════════════════════════════"
