| Model | Size | Latency (1 thread) | Lab accuracy | Lab macro-F1 | Field accuracy (95% CI) | Field macro-F1 | Field: answered / right when answered |
|---|---|---|---|---|---|---|---|
| 2018 model | 2.09 MB | 1.7 ms | 89.4% | 0.859 | 25.0% (16%–37%) | 0.151 | 97% / 26% |
| v2 lab-only INT8 | 2.75 MB | 4.5 ms | 95.5% | 0.943 | 27.5% (18%–39%) | 0.199 | 48% / 39% |
| v2 FP32 | 8.94 MB | 7.2 ms | 96.4% | 0.960 | 50.7% (39%–62%) | 0.494 | 55% / 74% |
| v2 FP16 | 4.54 MB | 7.0 ms | 96.4% | 0.960 | 50.7% (39%–62%) | 0.494 | 55% / 74% |
| v2 INT8 | 2.75 MB | 4.5 ms | 96.8% | 0.964 | 52.2% (41%–64%) | 0.518 | 59% / 73% |
