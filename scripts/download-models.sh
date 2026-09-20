#!/usr/bin/env bash
# Download the Project Foundry pilot model set (GGUF) to ./models.
#
# Requirements: huggingface-cli  (pip install -U "huggingface_hub[cli]")
#
# Q4_K_M is the default quant. For the coder, consider Q5_K_M / Q6_K if RAM allows
# (see docs/03-models.md). Adjust the --include patterns to change quants.
set -euo pipefail

MODELS_DIR="${1:-./models}"
mkdir -p "$MODELS_DIR"

if ! command -v huggingface-cli >/dev/null 2>&1; then
  echo "error: huggingface-cli not found. Run: pip install -U 'huggingface_hub[cli]'" >&2
  exit 1
fi

download() {
  local repo="$1" pattern="$2"
  echo "==> ${repo}  (${pattern})"
  huggingface-cli download "$repo" --include "$pattern" --local-dir "$MODELS_DIR"
}

download bartowski/Qwen2.5-72B-Instruct-GGUF          "*Q4_K_M.gguf"
download bartowski/Qwen2.5-Coder-32B-Instruct-GGUF    "*Q4_K_M.gguf"
download bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF  "*Q4_K_M.gguf"
download gpustack/bge-m3-GGUF                         "*.gguf"

echo
echo "Done. Models are in ${MODELS_DIR}"
echo "Next: serve them with llama-server (see docs/04-inference-stack.md)."
