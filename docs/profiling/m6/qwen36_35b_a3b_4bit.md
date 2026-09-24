### `unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit`

Apple M6 · 32 GB · runs=3 (long=1) · warmup=1 · gen=128 · temperature 0 · medians

| Config | Context (prompt tok) | Prefill tok/s | TTFT s | Decode tok/s | Peak GPU GB | Swap Δ GB | Min free % | Checks |
|---|---|---|---|---|---|---|---|---|
| Vanilla | 512 (548) | 807.6 | 0.69 | 46.7 | 20.38 | 0.0 | 26 | ok |
| Vanilla | 2048 (2346) | 968.9 | 2.46 | 45.46 | 20.96 | 0.0 | 27 | ok |
| Vanilla | 8192 (9809) | 849.2 | 11.63 | 43.42 | 21.06 | 0.0 | 26 | ok |
| Vanilla | 32768 (40829) | 634.9 | 64.6 | 35.08 | 22.38 | 0.0 | 20 | ok |
| SSD | 512 (548) | 320.6 | 1.7 | 13.22 | 5.99 | 0.0 | 72 | ok |
| SSD | 2048 (2356) | 401.6 | 5.92 | 13.12 | 6.24 | 0.0 | 71 | ok |
| SSD | 8192 (9811) | 402.6 | 24.51 | 12.85 | 6.6 | 0.0 | 72 | ok |
| SSD | 32768 (40806) | 340.2 | 120.24 | 11.91 | 7.73 | 0.0 | 67 | ok |
