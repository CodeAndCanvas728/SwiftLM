### `mlx-community/Qwen3.8-27B-4bit`

Apple M6 · 32 GB · runs=3 (long=1) · warmup=1 · gen=128 · temperature 0 · medians

| Config | Context (prompt tok) | Prefill tok/s | TTFT s | Decode tok/s | Peak GPU GB | Swap Δ GB | Min free % | Checks |
|---|---|---|---|---|---|---|---|---|
| Vanilla | 512 (548) | 105.2 | 5.33 | 9.14 | 16.45 | 0.0 | 40 | ok |
| Vanilla | 2048 (2346) | 108.2 | 21.69 | 8.84 | 16.15 | 0.0 | 41 | ok |
| Vanilla | 8192 (9809) | 96.3 | 101.9 | 8.57 | 16.68 | 0.0 | 33 | ok |
| Vanilla | 32768 (40829) | 88.2 | 463.18 | 7.92 | 19.56 | 0.7 | 27 | ok |
| TurboKV | 512 (548) | 102.1 | 5.36 | 9.26 | 16.5 | 0.0 | 40 | ok |
| TurboKV | 2048 (2356) | 108.3 | 21.79 | 9.15 | 16.07 | 0.0 | 41 | ok |
| TurboKV | 8192 (9811) | 98.2 | 99.97 | 8.29 | 16.82 | 0.0 | 33 | ok |
| TurboKV | 32768 (40806) | 85.1 | 479.54 | 7.29 | 19.56 | 1.52 | 32 | ok |
