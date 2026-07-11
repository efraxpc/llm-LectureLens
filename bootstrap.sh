#!/usr/bin/env bash
# bootstrap.sh — prepara o ambiente do projeto do zero, com um único comando.
#
# Uso:
#   ./bootstrap.sh   # cria o venv, instala tudo, registra o kernel, prepara o .env
#                    # e mostra os comandos para executar cada notebook (NÃO os executa).
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
  echo "[1/4] Criando ambiente virtual em $VENV ..."
  "$PYTHON" -m venv "$VENV"
else
  echo "[1/4] Ambiente virtual $VENV já existe — reutilizando."
fi
echo "      Instalando dependências de requirements.txt (pode demorar na 1ª vez) ..."
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r requirements.txt

# ── 2. Kernel do Jupyter ───────────────────────────────────────────────────────
echo "[2/4] Registrando o kernel do Jupyter ($KERNEL) ..."
"$VENV/bin/python" -m ipykernel install --user --name="$KERNEL" \
  --display-name "Python (llm_project)" >/dev/null

# ── 3. Arquivo .env com as chaves (devem ser SUAS — ver INSTALLATION.md) ──────
# Cria o .env sozinho e pede as chaves que faltarem, para bastar UM comando.
echo "[3/4] Preparando o arquivo .env ..."
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

# ── 4. Ambiente pronto — como executar os notebooks ───────────────────────────
echo "[4/4] Ambiente pronto. Os notebooks NÃO foram executados."

printf '\n'
printf '   %s┏━ Como executar os notebooks %s━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$CY" "$CY" "$R"
printf '   %s┃%s\n' "$CY" "$R"
printf '   %s┃%s  %sⓘ  Ao executar, a primeira corrida completa:%s\n' "$CY" "$R" "$AM" "$R"
printf '   %s┃%s     • baixa ~2,4 GB de modelos locais de tradução (C01);\n' "$CY" "$R"
printf '   %s┃%s     • gasta ~US$ 2,0–2,5 na API do Gemini (8 traduções com o\n' "$CY" "$R"
printf '   %s┃%s       Pro em C01 + centavos em C02–C05), na conta da SUA chave;\n' "$CY" "$R"
printf '   %s┃%s     • leva ~20–40 min, dependendo de GPU e conexão.\n' "$CY" "$R"
printf '   %s┃%s\n' "$CY" "$R"

# ── Opção A · Jupyter Lab ──
printf '   %s┃%s  %sA · Jupyter Lab %s(interface no navegador)%s\n' "$CY" "$R" "$B" "$D" "$R"
printf '   %s┃%s     %s%s/bin/jupyter lab%s\n' "$CY" "$R" "$VE" "$VENV" "$R"
printf '   %s┃%s     %s→ abra cada .ipynb e escolha o kernel "Python (llm_project)"%s\n' "$CY" "$R" "$GR" "$R"
printf '   %s┃%s\n' "$CY" "$R"

# ── Opção B · Editor (VS Code, Cursor, PyCharm…) ──
printf '   %s┃%s  %sB · Editor de texto %s(VS Code, Cursor, PyCharm…)%s\n' "$CY" "$R" "$B" "$D" "$R"
printf '   %s┃%s     %scode .%s   %s# abre o projeto (ou abra o .ipynb no seu editor)%s\n' "$CY" "$R" "$VE" "$R" "$D" "$R"
printf '   %s┃%s     %s→ instale as extensões Python + Jupyter, se faltarem%s\n' "$CY" "$R" "$GR" "$R"
printf '   %s┃%s     %s→ abra o .ipynb e clique em "Select Kernel" (canto sup. dir.)%s\n' "$CY" "$R" "$GR" "$R"
printf '   %s┃%s     %s→ escolha o interpretador .venv  (Python (llm_project))%s\n' "$CY" "$R" "$GR" "$R"
printf '   %s┃%s     %s→ rode as células com Shift+Enter%s\n' "$CY" "$R" "$GR" "$R"
printf '   %s┃%s\n' "$CY" "$R"

# ── Opção C · Linha de comando, um notebook por vez ──
printf '   %s┃%s  %sC · Linha de comando, um por vez %s(ordem de dependência)%s\n' "$CY" "$R" "$B" "$D" "$R"
printf '   %s┃%s     %sⓘ  rode o C01 primeiro — ele gera data/processed/;%s\n' "$CY" "$R" "$D" "$R"
printf '   %s┃%s     %s   se já houver 8 aulas processadas, pode pular o C01.%s\n' "$CY" "$R" "$D" "$R"
n=0
for NB in "${NOTEBOOKS[@]}"; do
  n=$((n + 1))
  printf '   %s┃%s     %s%d)%s %s%s/bin/jupyter nbconvert --to notebook --execute --inplace \\%s\n' \
         "$CY" "$R" "$AM" "$n" "$R" "$VE" "$VENV" "$R"
  printf '   %s┃%s          %s--ExecutePreprocessor.kernel_name=%s \\%s\n' "$CY" "$R" "$VE" "$KERNEL" "$R"
  printf '   %s┃%s          %s--ExecutePreprocessor.timeout=3600 %s%s\n' "$CY" "$R" "$VE" "$NB" "$R"
done
printf '   %s┃%s\n' "$CY" "$R"
printf '   %s┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "$CY" "$R"
printf '\n'
