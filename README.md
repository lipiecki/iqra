# iQRA

This repo hosts replication code for the paper [A. Lipiecki & B. Uniejewski, *Isotonic Quantile Regression Averaging for uncertainty quantification of electricity price forecasts*, arXiv.2507.15079](https://doi.org/10.48550/arXiv.2507.15079)

All the commands provided in this README are meant to be executed in a shell from this directory.

## Base forecasts dataset

This package does not include input or output data files. They are hosted as individual files in the [`inputs/`](https://huggingface.co/datasets/lipiecki/iqra/tree/main/inputs) and [`outputs/`](https://huggingface.co/datasets/lipiecki/iqra/tree/main/outputs) directories of the [iQRA dataset on Hugging Face](https://huggingface.co/datasets/lipiecki/iqra):

- `inputs/` contains the base point forecasts and is downloaded by the default setup command.
- `outputs/` contains precomputed probabilistic forecasts and weights and is downloaded only with `--with-outputs`. These files weigh around 8GB. Computing all postprocessing methods can take a couple of days on a consumer grade laptop, so downloading the outputs is recommended.

The `inputs/` directory contains 288 HDF5 files named `{model}-{market}-r{size}-h{hour}.pointf`. They contain NARX and XGB ensemble forecasts for the German (`DE`) and French (`FR`) day-ahead markets, ensemble sizes 10, 25, and 50, and hours 1–24. Each file stores predictions, observations, and integer dates.

The supplied files cover 1 January 2019 through 31 December 2025. The first 364 days form the calibration window and the evaluation period covers 2020–2025.

## Structure
- `src/`: directory with forecast, evaluation, and trading function definitions
- `scripts/`: directory with executable replication scripts
    - `scripts/setup.jl`: instantiates the Julia project and downloads the files from HuggingFace
    - `scripts/run.jl`: generates probabilistic forecasts
    - `scripts/run_all.sh`: generates all probabilistic forecasts in parallel
    - `scripts/eval.jl`: prints the results in tabular form
    - `scripts/timing.jl`: measures computation times
    - `scripts/plot.jl`: reproduces the figures
- `inputs/`: downloaded base point forecasts (automatically created)
- `outputs/`: generated probabilistic forecasts, saved weightsd and timing files (automatically created)
- `figures/`: directory with generated figures (automatically created)

## Computing environment

This repository is written purely in Julia. The results were computed on a Linux machine with AMD EPYC 9965 CPU and 1TB of RAM, running on Ubuntu 24.04.4 LTS. The timing results were obtained on macOS machine running with the Apple M2 Pro chip and 16GB of RAM. The exact versions of all dependencies are included in the `Manifest.toml` file. Runtime results depend on the hardware and package versions.

### Install Julia

The recommended way to install Julia is via [juliaup](https://julialang.org/install/). After installing juliaup, download Julia 1.12.0 and set it as default with:

```sh
juliaup add 1.12.0
juliaup default 1.12.0
```

### Setup project

Install the required dependencies and download `inputs/` from Hugging Face,

```sh
julia --project=. scripts/setup.jl
```

To also download the available precomputed files under `outputs/`, run:

```sh
julia --project=. scripts/setup.jl --with-outputs
```

Setup skips existing files. If the setup fails during download, simply rerun the command.

## Reproducing results

### Tables

If the `outputs` folder was not downloaded, first computed the probabilistic forecasts. A single method, point model, market, ensemble size, and hour can be processed with:

```sh
julia --project=. scripts/run.jl iqra narx DE 25 1
```

Valid methods are `hs`, `cp`, `idr`, `qra`, `sqra`, `qrm`, `sqrm`, `lqra`, `iqra`, and `isqra`. Point models are `narx` and `xgb`, markets are `DE` and `FR`, and ensemble sizes are 10, 25, and 50. Existing valid forecast files are skipped. 

You can also generate the complete set of results with parallel jobs:

```sh
bash scripts/run_all.sh {X}
```
The parallel full run also requires [GNU Parallel](https://www.gnu.org/software/parallel/). The shell script runs `X` parallel Julia processes. Each process handles one combination and HiGHS remains limited to one internal thread. 

> [!NOTE]
> `run_all.sh` is computationally intensive and requires around 8GB of storage. Generating the complete set of results on the AMD EPYC 9965 using all cores takes up to 20 hours. 

After generating or downloading the required forecasts, reproduce the tables with the commands below.

| Output | Script |
| --- | --- |
| Tables 1 and 11: yearly CRPS | `julia --project=. scripts/eval.jl crps` |
| Tables 2 and 12: CRPS by ensemble size | `julia --project=. scripts/eval.jl ensemble` |
| Tables 3 and 13: Model Confidence Sets | `julia --project=. scripts/eval.jl mcs` |
| Tables 4, 5, 14 and 15: ACE and PIPS | `julia --project=. scripts/eval.jl intervals` |
| Table 8: point-forecast MAE | `julia --project=. scripts/eval.jl mae` |
| Tables 9 and 16: trading results | `julia --project=. scripts/eval.jl trading` |

Tables 6 and 10 are not included because they don't represent any obtained results.

CRPS follows the paper's average-pinball convention, ACE is reported as nominal minus empirical coverage in percentage points.

To reproduce Table 7 on your machinge, first measure ten single-day runs for each ensemble size:

```sh
julia --project=. scripts/timing.jl 10
julia --project=. scripts/timing.jl 25
julia --project=. scripts/timing.jl 50
```

Each observation measures the generation of 99 quantiles for all 24 hours. Compilation is performed before measurement.

The number of repetitions is fixed at 10, as in the paper. Timing results are saved as `outputs/timers/ensemble{size}.jld2`. You can then run

`julia --project=. scripts/eval.jl timing` for a time comparison analogous to Table 7. 

> [!NOTE]
> The timing results can vary significantly depending on the machine. Timing all methods and ensemble sizes on M2 Pro took around 4 hours.

### Plots

Reproduce a figure with:

```sh
julia --project=. scripts/plot.jl {X}
```

where `{X}` is the figure number from the paper.

| Output | Script |
| --- | --- |
| Figure 3: NARX GW comparison | `julia --project=. scripts/plot.jl 3` |
| Figure 4: NARX trading results | `julia --project=. scripts/plot.jl 4` |
| Figure 5: coefficient selection frequencies | `julia --project=. scripts/plot.jl 5` |
| Figure 6: XGB GW comparison | `julia --project=. scripts/plot.jl 6` |
| Figure 7: XGB trading results | `julia --project=. scripts/plot.jl 7` |

The resulting files are saved in the `figures` directory. Figures 1 and 2 are not reproduced because they don't represent any obtained results.

## Authors and license

The reproducibility package was assembled by Arkadiusz Lipiecki on 6 November 2026. Questions can be sent to `arkadiusz.lipiecki@pwr.edu.pl`.

The code is shared under the [MIT license](LICENSE).
