### `mlx-community/gemma-4-26b-a4b-it-8bit`

Apple M6 · 32 GB · runs=3 (long=1) · warmup=1 · gen=128 · temperature 0 · medians

| Config | Context (prompt tok) | Prefill tok/s | TTFT s | Decode tok/s | Peak GPU GB | Swap Δ GB | Min free % | Checks |
|---|---|---|---|---|---|---|---|---|
| Vanilla | 512 | — | — | — | 3.33 | 3.06 | 28 | **MEM_ABORT** swap grew 3.1 GB |
| Vanilla | 2048 | — | — | — | — | — | — | **SKIPPED_AFTER_ABORT**  |
| Vanilla | 8192 | — | — | — | — | — | — | **SKIPPED_AFTER_ABORT**  |
| Vanilla | 32768 | — | — | — | — | — | — | **SKIPPED_AFTER_ABORT**  |
| SSD | 512 (528) | 219.6 | 2.44 | 8.78 | 6.95 | 0.0 | 73 | ok |
| SSD | 2048 (2291) | 193.7 | 11.93 | 7.7 | 7.32 | 0.0 | 69 | ok |
| SSD | 8192 (9543) | 138.5 | 68.94 | 6.92 | 7.58 | 0.0 | 53 | ok |
| SSD | 32768 | — | — | — | 5.8 | 2.09 | 32 | **MEM_ABORT** swap grew 2.1 GB |
