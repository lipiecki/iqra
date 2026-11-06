#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)
cd "$root"

cores=${1:-1}

echo "Running with $cores parallel workers"
parallel --jobs "$cores" --halt soon,fail=1 \
    julia --project=. scripts/run.jl {1} {2} {3} {4} {5} \
    ::: hs cp idr qra sqra qrm sqrm lqra iqra isqra \
    ::: narx xgb \
    ::: DE FR \
    ::: 10 25 50 \
    ::: {1..24}