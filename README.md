# Gemini Voice Automation (GVA)

O Gemini Voice Automation (GVA) é uma interface de automação via terminal que permite o envio de comandos e consultas através de captura de áudio nativa. O projeto integra-se ao Gemini CLI para processar intenções do usuário com base no contexto do diretório de execução.

## Funcionalidades (v2.0.0)

- **Execução Automatizada:** Processamento direto do áudio via Gemini CLI sem necessidade de intervenção manual após a gravação.
- **Feedback Visual (Loader UI):** Indicador dinâmico de processamento (spinner) em background para mitigar "ansiedade de linha de comando" durante a inferência da IA.
- **Consciência de Contexto (Smart Prompting):** Injeção automática da listagem de arquivos locais no prompt da IA, permitindo consultas contextuais sobre o diretório atual.
- **Configuração Modular:** Parametrização de duração, prompts padrão e motores de IA através do arquivo `.gvarc`.
- **Gestão de Cache e Recursos (Micro-FinOps):** Rotina de limpeza automática (housekeeping) para otimização de armazenamento local.
- **Robustez e Integridade:**
  - *Graceful Degradation:* Tratamento de sinais (ex: `Ctrl+C`) que encerra processos em background com segurança e expurga artefatos parciais (arquivos `.wav`) do disco.
  - *Fail-Fast & Validação Estrita:* Verificação prévia de dependências críticas (`arecord` e engine) e proteção via Regex para blindar a leitura de parâmetros contra *inputs* malformados.

## Arquitetura e Componentes

A solução é baseada em princípios de baixa latência e portabilidade em sistemas Linux:
- **Captura:** Utiliza o subsistema ALSA via ferramenta `arecord`.
- **Orquestração:** Scripting em Bash com tratamento de sinais e logs estruturados.
- **Interface de IA:** Comunicação multimodal via fluxo binário de áudio.

## Guia de Instalação e Configuração

### 1. Requisitos de Sistema
O projeto é compatível com distribuições baseadas em Debian/Ubuntu, Fedora e Arch Linux que possuam o pacote `alsa-utils` instalado.

### 2. Procedimento de Instalação
1. Clone o repositório ou baixe os arquivos do projeto.
2. Atribua permissões de execução ao script principal:
   ```bash
   chmod +x gemini-voice.sh
   ```
3. (Opcional) Configure um alias global para facilitar o acesso:
   ```bash
   echo "alias augustus='$(pwd)/gemini-voice.sh'" >> ~/.bashrc && source ~/.bashrc
   ```

### 3. Utilização
Execute o comando configurado no terminal:
```bash
augustus
```
O sistema iniciará a captura de áudio conforme a duração definida. Após o término, o áudio e o contexto do diretório serão enviados automaticamente para processamento.

## Personalização

As variáveis de ambiente do projeto podem ser ajustadas no arquivo `.gvarc`:
- `DEFAULT_DURATION`: Tempo de captura em segundos.
- `AI_ENGINE`: Caminho absoluto para o binário da engine de IA.
- `DEFAULT_PROMPT`: Instrução base para a transcrição e execução.

---
*Desenvolvido por Rodolfo e Augustus (AI Arquiteto).*
