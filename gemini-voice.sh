#!/bin/bash

# ==============================================================================
# Gemini Voice Automation (GVA) - "Modo KITT"
# Descrição: Assistente de voz modular para terminal.
# Versão: 2.0.0 (Config-Driven + Loader UI)
# ==============================================================================

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$SCRIPT_DIR/.gvarc"

# --- Carregar Configurações (Default + Override) ---
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    DEFAULT_DURATION=5
    AI_ENGINE="gemini"
    DEFAULT_PROMPT="Transcreva e responda."
    MAX_CACHE_FILES=5
fi

# Sobrescrever via argumentos se fornecidos
DURATION=${1:-$DEFAULT_DURATION}
CUSTOM_PROMPT=${2:-$DEFAULT_PROMPT}
AUDIO_DIR="$HOME/.cache/gemini-voice"

# --- Funções de Sistema ---
log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
log_error()   { echo -e "\e[31m[ERROR]\e[0m $1"; }

# --- Validações de Segurança e Integridade ---
if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    log_error "Parâmetro DURATION inválido: deve ser um número inteiro."
    exit 1
fi
if ! [[ "$MAX_CACHE_FILES" =~ ^[0-9]+$ ]]; then
    log_error "Parâmetro MAX_CACHE_FILES inválido: deve ser um número inteiro."
    exit 1
fi

check_dependencies() {
    if ! command -v arecord &> /dev/null; then
        log_error "Dependência 'arecord' (alsa-utils) não encontrada. (Fail-Fast)"
        exit 1
    fi
    if ! command -v "$AI_ENGINE" &> /dev/null; then
        log_error "AI_ENGINE '$AI_ENGINE' não encontrada ou não é executável. (Fail-Fast)"
        exit 1
    fi
}

cleanup() {
    echo -e "\n"
    log_info "Execução interrompida pelo usuário (Graceful Degradation)."
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
    fi
    if [[ -n "$AUDIO_FILE" ]] && [[ -f "$AUDIO_FILE" ]]; then
        rm -f "$AUDIO_FILE"
    fi
    exit 1
}

# Tratamento de Sinais
trap cleanup SIGINT SIGTERM

housekeeping() {
    ls -t "$AUDIO_DIR"/input_*.wav 2>/dev/null | tail -n +$((MAX_CACHE_FILES + 1)) | xargs -I {} rm {}
}

# --- Execução ---
check_dependencies
mkdir -p "$AUDIO_DIR"
AUDIO_FILE="$AUDIO_DIR/input_$(date +%Y%m%d_%H%M%S).wav"

echo -e "\n\e[1;35m⚡ GVA v2.0.0 | ENGINE: $(basename "$AI_ENGINE")\e[0m"
echo -e "\e[1;33m🎙️  OUVINDO... ($DURATION seg)\e[0m"
echo -e "----------------------------------------------------"

arecord -f cd -d "$DURATION" "$AUDIO_FILE" 2>/dev/null &
PID=$!

for ((i=0; i<DURATION; i++)); do
    echo -ne "Recording... $((DURATION-i))s \r"
    sleep 1
done
wait $PID

if [ $? -eq 0 ]; then
    echo -e "\r\e[32m✅ Captura Concluída!                          \e[0m"
    echo -e "----------------------------------------------------"
    
    # --- Inteligência de Contexto (NOVO) ---
    # Captura os primeiros 20 arquivos da pasta atual para não sobrecarregar o prompt
    FILE_CONTEXT=$(ls -F | head -n 20 | tr '\n' ', ')
    CURRENT_DIR=$(pwd)
    
    SMART_PROMPT="[CONTEXTO LOCAL]
Diretório Atual: $CURRENT_DIR
Arquivos Presentes: $FILE_CONTEXT
---
Instrução do Usuário (via áudio): $CUSTOM_PROMPT"

    # Arquivo temporário para capturar a resposta
    RESPONSE_FILE=$(mktemp)
    
    # Executa a engine em background
    "$AI_ENGINE" "@$AUDIO_FILE $SMART_PROMPT" > "$RESPONSE_FILE" 2>&1 &
    AI_PID=$!
    
    # Indicador visual dinâmico (Loader v2.0)
    spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $AI_PID 2>/dev/null; do
        temp="${spinstr#?}"
        printf "\r\e[36m%c\e[0m Processando áudio e contexto..." "$spinstr"
        spinstr="${temp}${spinstr%\"$temp\"}"
        sleep 0.1
    done
    printf "\r\e[K" # Limpa a linha do loader
    
    # Exibe a resposta final e remove arquivo temporário
    cat "$RESPONSE_FILE"
    rm -f "$RESPONSE_FILE"
    
    housekeeping
else
    log_error "Erro no hardware de áudio."
fi
