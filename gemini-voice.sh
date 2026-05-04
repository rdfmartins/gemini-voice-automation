#!/bin/bash

# ==============================================================================
# Gemini Voice Automation (GVA) - "Modo KITT"
# Descrição: Assistente de voz modular para terminal.
# Versão: 2.1.1 (Cache Workspace Fix)
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
AUDIO_DIR="$SCRIPT_DIR/.audio_cache"

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

configure_engine() {
    echo -e "\n\e[33m⚠️  AI_ENGINE não encontrada ou inválida: $AI_ENGINE\e[0m"
    echo -e "Para utilizar o GVA, precisamos do caminho absoluto para o binário do Gemini CLI.\n"
    
    local auto_path=$(which gemini 2>/dev/null)
    if [[ -z "$auto_path" ]]; then
        auto_path=$(find ~/.nvm/versions/node ~/.npm-global/bin /usr/local/bin -maxdepth 4 -name gemini -type f -executable 2>/dev/null | head -n 1)
    fi

    local NEW_ENGINE=""
    if [[ -n "$auto_path" ]]; then
        echo -e "💡 Encontrei uma possível instalação em: \e[36m$auto_path\e[0m"
        read -p "Deseja usar este caminho? [Y/n]: " use_auto
        use_auto=${use_auto:-Y}
        if [[ "$use_auto" =~ ^[Yy]$ ]]; then
            NEW_ENGINE="$auto_path"
        fi
    fi

    if [[ -z "$NEW_ENGINE" ]]; then
        read -p "Digite o caminho absoluto para o binário: " NEW_ENGINE
    fi

    if ! command -v "$NEW_ENGINE" &> /dev/null; then
        log_error "O caminho fornecido é inválido. Abortando."
        exit 1
    fi

    if grep -q "^AI_ENGINE=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^AI_ENGINE=.*|AI_ENGINE=\"$NEW_ENGINE\"|" "$CONFIG_FILE"
    else
        echo "AI_ENGINE=\"$NEW_ENGINE\"" >> "$CONFIG_FILE"
    fi
    
    AI_ENGINE="$NEW_ENGINE"
    log_success "Caminho salvo em $CONFIG_FILE!\n"
}

check_dependencies() {
    if ! command -v arecord &> /dev/null; then
        log_error "Dependência 'arecord' (alsa-utils) não encontrada. (Fail-Fast)"
        exit 1
    fi
    if ! command -v "$AI_ENGINE" &> /dev/null; then
        configure_engine
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

echo -e "\n\e[1;35m[ GVA v2.1.1 | ENGINE: $(basename "$AI_ENGINE") ]\e[0m"
echo -e "\e[1;33m> OUVINDO... ($DURATION seg)\e[0m"
echo -e "----------------------------------------------------"

arecord -f cd -d "$DURATION" "$AUDIO_FILE" 2>/dev/null &
PID=$!

for ((i=0; i<DURATION; i++)); do
    if ! kill -0 $PID 2>/dev/null; then
        break
    fi
    echo -ne "Recording... $((DURATION-i))s \r"
    sleep 1
done
wait $PID

if [ $? -eq 0 ]; then
    echo -e "\r\e[32m✅ Captura Concluída!                          \e[0m"
    echo -e "----------------------------------------------------"
    
    # --- Inteligência de Contexto ---
    # Captura os primeiros 20 arquivos da pasta atual para não sobrecarregar o prompt
    FILE_CONTEXT=$(ls -F | head -n 20 | tr '\n' ', ')
    CURRENT_DIR=$(pwd)

    SMART_PROMPT="[CONTEXTO LOCAL]
Diretório Atual: $CURRENT_DIR
Arquivos Presentes: $FILE_CONTEXT
---
Instrução do Usuário (via áudio): $CUSTOM_PROMPT"

    log_info "Abrindo sessão interativa com contexto local..."
    echo -e "----------------------------------------------------"

    # Bug Fix v2.1.1: O cache de áudio foi movido para dentro do projeto (.audio_cache)
    # Isso evita que as tools nativas do Gemini CLI (read_file, list_directory) falhem
    # por estarem acessando caminhos fora do 'workspace boundary'.
    # A flag -i injeta o prompt e mantém a sessão interativa aberta.
    "$AI_ENGINE" -i "@$AUDIO_FILE
$SMART_PROMPT"

    housekeeping
else
    log_error "Erro no hardware de áudio."
fi
