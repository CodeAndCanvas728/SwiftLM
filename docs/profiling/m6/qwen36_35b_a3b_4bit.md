### `unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit`

Apple M6 · 32 GB · runs=3 (long=1) · warmup=1 · gen=128 · temperature 0 · medians

| Config | Context (prompt tok) | Prefill tok/s | TTFT s | Decode tok/s | Peak GPU GB | Swap Δ GB | Min free % | Checks |
|---|---|---|---|---|---|---|---|---|
| Vanilla | 512 (548) | 713.8 | 0.78 | 46.97 | 19.78 | 0.0 | 27 | ok |
| Vanilla | 2048 (2346) | 967.5 | 2.45 | 45.72 | 20.06 | 0.0 | 28 | ok |
| Vanilla | 8192 (9809) | 857.8 | 11.52 | 43.43 | 20.41 | 0.0 | 27 | ok |
| Vanilla | 32768 (40829) | 615.3 | 66.64 | 36.05 | 21.54 | 0.0 | 22 | ok |
| SSD | 512 (548) | 256.1 | 2.12 | 13.23 | 5.59 | 0.0 | 73 | ok |
| SSD | 2048 (2356) | 403.3 | 5.87 | 13.03 | 5.57 | 0.0 | 74 | ok |
| SSD | 8192 (9811) | 400.6 | 24.57 | 12.72 | 5.56 | 0.0 | 74 | ok |
| SSD | 32768 (40806) | 335.9 | 121.74 | 12.03 | 5.8 | 0.0 | 73 | ok |
