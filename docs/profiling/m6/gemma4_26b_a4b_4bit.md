### `mlx-community/gemma-4-26b-a4b-it-4bit`

Apple M6 · 32 GB · runs=3 (long=1) · warmup=1 · gen=128 · temperature 0 · medians

| Config | Context (prompt tok) | Prefill tok/s | TTFT s | Decode tok/s | Peak GPU GB | Swap Δ GB | Min free % | Checks |
|---|---|---|---|---|---|---|---|---|
| Vanilla | 512 (534) | 858.5 | 0.68 | 53.27 | 15.15 | 0.0 | 43 | ok |
| Vanilla | 2048 (2285) | 997.6 | 2.38 | 50.08 | 15.78 | 0.0 | 40 | ok |
| Vanilla | 8192 (9544) | 913.7 | 10.67 | 44.93 | 16.54 | 0.0 | 37 | ok |
| Vanilla | 32768 (39773) | 749.6 | 53.9 | 31.44 | 19.13 | 0.0 | 33 | ok |
| Vanilla | 65536 (80711) | 625.1 | 130.63 | 21.83 | 20.19 | 0.0 | 18 | ok |
| TurboKV | 512 (532) | 882.9 | 0.65 | 53.13 | 15.02 | 0.0 | 44 | ok |
| TurboKV | 2048 (2299) | 918.9 | 2.65 | 53.22 | 15.77 | 0.0 | 41 | needle 1/3, degen 0 |
| TurboKV | 8192 | — | — | — | 0.35 | 0.0 | 87 | **REQUEST_FAIL** <urlopen error [Errno 61] Connection refused> |
| TurboKV | 32768 | — | — | — | — | — | — | **SKIPPED_AFTER_ABORT**  |
| TurboKV | 65536 | — | — | — | — | — | — | **SKIPPED_AFTER_ABORT**  |
| MTP | None | — | — | — | — | — | — | **START_FAIL**  |
