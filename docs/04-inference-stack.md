# 04 - Inference Stack

Local inference via `llama.cpp`. It loads GGUF models and exposes an OpenAI-compatible HTTP API that the agents call on `localhost`. No cloud, no API keys, no per-token billing.

## Install llama.cpp

```bash
brew install llama.cpp
```

Verify:

```bash
llama-server --version
```

## Download the pilot model set

```bash
./scripts/download-models.sh
```

Or pull a single model straight from Hugging Face and serve it in one step (llama.cpp supports `-hf` for direct-from-Hub):

```bash
llama-server -hf bartowski/Qwen2.5-72B-Instruct-GGUF:Q4_K_M
```

## Serve a model

Run one `llama-server` per model, each on its own port:

```bash
# General workhorse - port 8080
llama-server \
  --hf-repo bartowski/Qwen2.5-72B-Instruct-GGUF \
  --hf-file '*Q4_K_M.gguf' \
  --port 8080 \
  --ctx-size 8192 \
  --n-gpu-layers 99

# Coder - port 8081
llama-server \
  --hf-repo bartowski/Qwen2.5-Coder-32B-Instruct-GGUF \
  --hf-file '*Q4_K_M.gguf' \
  --port 8081 \
  --ctx-size 8192 \
  --n-gpu-layers 99

# Reasoning (DeepSeek harness) - port 8082
llama-server \
  --hf-repo bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF \
  --hf-file '*Q4_K_M.gguf' \
  --port 8082 \
  --ctx-size 8192 \
  --n-gpu-layers 99
```

`--n-gpu-layers 99` offloads everything to the GPU (Apple Silicon Metal). If a model is too big, lower it and let some layers spill to CPU.

### Verify

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Reply with the single word: ok"}]
  }'
```

You should get an OpenAI-shaped JSON response with `choices[0].message.content`.

## Run as a background service (survives reboot)

`llama-server` is a foreground process. To keep it running headless, wrap each in a `launchd` LaunchAgent. Create a plist per model (or use a small supervisor script):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.foundry.qwen72b</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/llama-server</string>
    <string>--hf-repo</string><string>bartowski/Qwen2.5-72B-Instruct-GGUF</string>
    <string>--hf-file</string><string>*Q4_K_M.gguf</string>
    <string>--port</string><string>8080</string>
    <string>--ctx-size</string><string>8192</string>
    <string>--n-gpu-layers</string><string>99</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
```

Save to `~/Library/LaunchAgents/ai.foundry.qwen72b.plist`, then:

```bash
launchctl load ~/Library/LaunchAgents/ai.foundry.qwen72b.plist
```

## MLX (Apple-native alternative)

If you prefer Apple's own stack, `mlx_lm.server` serves the same OpenAI-compatible API:

```bash
pip install mlx-lm
mlx_lm.server --model mlx-community/Qwen2.5-72B-Instruct-4bit --port 8080
```

Same protocol, same ports, same agent wiring. The rest of this guide is agnostic between llama.cpp and MLX. llama.cpp is used in the examples because its GGUF ecosystem is larger.

## Optional: a router in front

At pilot scale you do **not** need one - each agent points at its model's port directly. When you build the 20-30 person fleet and run models across several boxes, put [LiteLLM](https://github.com/BerriAI/litellm) in front as a single OpenAI-compatible endpoint that routes, queues, and (if you choose) falls back to a cloud model. See `docs/08-scaling.md`.

## Pitfalls

- **Ports collide.** One model per port. 8080 / 8081 / 8082 in the examples; keep a map.
- **`--n-gpu-layers` too high.** If startup fails with an out-of-memory error, lower it (e.g. `--n-gpu-layers 60`) and retry.
- **Context is memory.** `--ctx-size` (KV cache) costs RAM per concurrent session. 8192 is a safe default; raise it only if you have headroom.
- **First token is slow.** Large models take seconds to load and to produce the first token. That is normal; generation speed after that is what the sizing table in `docs/02-hardware.md` describes.
