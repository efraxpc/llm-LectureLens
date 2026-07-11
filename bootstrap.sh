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

# ── Cores (só em terminal interativo; respeita NO_COLOR) ───────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
  VE=$'\033[38;5;46m'; AM=$'\033[38;5;226m'; AZ=$'\033[38;5;27m'
  RO=$'\033[38;5;196m'; CY=$'\033[38;5;51m'; GR=$'\033[38;5;250m'; WH=$'\033[38;5;255m'
else
  B=""; D=""; R=""; VE=""; AM=""; AZ=""; RO=""; CY=""; GR=""; WH=""
fi

# ── Banner: logo INFNET + bandeiras do Brasil e da Venezuela ───────────────────
banner() {
  printf '\n'
  printf '   %s██╗███╗   ██╗███████╗███╗   ██╗███████╗████████╗%s\n' "$CY" "$R"
  printf '   %s██║████╗  ██║██╔════╝████╗  ██║██╔════╝╚══██╔══╝%s\n' "$CY" "$R"
  printf '   %s██║██╔██╗ ██║█████╗  ██╔██╗ ██║█████╗     ██║%s\n'    "$CY" "$R"
  printf '   %s██║██║╚██╗██║██╔══╝  ██║╚██╗██║██╔══╝     ██║%s\n'    "$CY" "$R"
  printf '   %s██║██║ ╚████║██║     ██║ ╚████║███████╗   ██║%s\n'    "$CY" "$R"
  printf '   %s╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝  ╚═══╝╚══════╝   ╚═╝%s\n'    "$CY" "$R"
  printf '\n'
  printf '   %s%sLectureLens%s %s· Sistemas Cognitivos com LLMs · INFNET%s\n' "$B" "$CY" "$R" "$D" "$R"
  printf '\n'
  printf '     %sBrasil%s             %sVenezuela%s\n' "$GR" "$R" "$GR" "$R"
  printf '     %s███████%s             %s███████%s\n' "$VE" "$R" "$AM" "$R"
  printf '     %s██%s%s███%s%s██%s             %s███████%s\n' "$VE" "$R" "$AM" "$R" "$VE" "$R" "$AM" "$R"
  printf '     %s██%s%s█%s%s█%s%s█%s%s██%s             %s██%s%s✦✦✦%s%s██%s\n' \
         "$VE" "$R" "$AM" "$R" "$AZ" "$R" "$AM" "$R" "$VE" "$R" "$AZ" "$R" "$WH" "$R" "$AZ" "$R"
  printf '     %s██%s%s███%s%s██%s             %s███████%s\n' "$VE" "$R" "$AM" "$R" "$VE" "$R" "$RO" "$R"
  printf '     %s███████%s             %s███████%s\n' "$VE" "$R" "$RO" "$R"
  printf '\n'
}
banner

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

# Provedor e URL de cada chave (mostrados no console ao pedi-la).
provedor_chave() { case "$1" in
    GEMINI_API_KEY)  echo "Google AI Studio" ;;
    HUGGINGFACE_KEY) echo "Hugging Face" ;;
    *)               echo "$1" ;;
  esac; }
url_chave() { case "$1" in
    GEMINI_API_KEY)  echo "https://aistudio.google.com/apikey" ;;
    HUGGINGFACE_KEY) echo "https://huggingface.co/settings/tokens" ;;
    *)               echo "" ;;
  esac; }

definir_chave() {  # $1 = nome da chave; grava/atualiza a linha no .env
  local nome="$1" valor tmp
  read -rs valor
  echo ""
  if [ -z "$valor" ]; then
    printf '   %s✗%s %s não pode ficar vazia — ver INSTALLATION.md.\n' "$RO" "$R" "$nome"
    exit 1
  fi
  tmp="$(mktemp)"
  grep -v "^${nome}=" .env > "$tmp" || true
  printf '%s=%s\n' "$nome" "$valor" >> "$tmp"
  mv "$tmp" .env
  printf '   %s✓%s %s salva no .env.\n' "$VE" "$R" "$nome"
}

n_chave=0
for CHAVE in GEMINI_API_KEY HUGGINGFACE_KEY; do
  n_chave=$((n_chave + 1))
  if ! grep -Eq "^${CHAVE}=.+" .env; then
    if [ -t 0 ]; then
      printf '\n'
      printf '   %s┃%s %sChave %d de 2%s  %s·%s  %s%s%s\n' \
             "$CY" "$R" "$B" "$n_chave" "$R" "$D" "$R" "$B" "$CHAVE" "$R"
      printf '   %s┃%s  cole a SUA chave do %s%s%s\n' \
             "$CY" "$R" "$B" "$(provedor_chave "$CHAVE")" "$R"
      printf '   %s┃%s  %s%s%s\n' "$CY" "$R" "$D" "$(url_chave "$CHAVE")" "$R"
      printf '   %s▸%s  cole aqui e aperte Enter %s(não será exibida)%s: ' "$AM" "$R" "$D" "$R"
      definir_chave "$CHAVE"
    else
      printf '\n   %s✗%s %s ausente ou vazia no .env, e não há terminal interativo.\n' "$RO" "$R" "$CHAVE"
      printf '   Preencha o .env à mão — instruções em INSTALLATION.md.\n'
      exit 1
    fi
  fi
done
printf '   %s✓%s .env OK — GEMINI_API_KEY e HUGGINGFACE_KEY presentes.\n' "$VE" "$R"

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
