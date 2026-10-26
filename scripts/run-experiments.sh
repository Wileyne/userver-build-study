#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="ghcr.io/userver-framework/ubuntu-22.04-userver"
DIGEST="sha256:fca9c8ac7e97b4e2b042d822facbb152aec10a9d4e09c0862e44c50640f3f303"
ANALYZER_COMMIT="55447756ff8af2f87e4a315f2ba637b9380363ea"

REPEATS="${REPEATS:-3}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! "$REPEATS" =~ ^[1-9][0-9]*$ ]]; then
    echo "REPEATS must be a positive integer" >&2
    exit 1
fi

# Host mode: start the pinned Docker image with the required limits.
if [[ "${1:-}" != "--inside-container" ]]; then
    RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"

    if docker info >/dev/null 2>&1; then
        DOCKER_CMD=(docker)
    else
        DOCKER_CMD=(sudo docker)
    fi

    "${DOCKER_CMD[@]}" run --rm \
        --cpus=4 \
        --cpuset-cpus=0-3 \
        --memory=8g \
        --memory-swap=8g \
        -e RUN_ID="$RUN_ID" \
        -e REPEATS="$REPEATS" \
        -e HOST_UID="$(id -u)" \
        -e HOST_GID="$(id -g)" \
        -e CCACHE_DISABLE=1 \
        -v "$ROOT_DIR:/workspace" \
        -w /workspace \
        "$IMAGE@$DIGEST" \
        bash /workspace/scripts/run-experiments.sh --inside-container
    exit
fi

# The remaining commands run inside Docker.
ROOT_DIR="/workspace"
SERVICE_DIR="$ROOT_DIR/benchmark_service"
RUN_DIR="$ROOT_DIR/results/reproducible-${RUN_ID}"
ANALYZER_SRC="/tmp/ClangBuildAnalyzer-src"
ANALYZER_BUILD="/tmp/ClangBuildAnalyzer-build"

mkdir -p "$RUN_DIR"

# Keep generated reports accessible to the host user, even on failure.
finish() {
    chown -R "${HOST_UID}:${HOST_GID}" "$RUN_DIR" 2>/dev/null || true
}
trap finish EXIT

echo "Installing build dependencies..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    clang-14 cmake ninja-build git build-essential time ca-certificates

echo "Building Clang Build Analyzer at commit ${ANALYZER_COMMIT}..."
git clone https://github.com/aras-p/ClangBuildAnalyzer.git "$ANALYZER_SRC"
git -C "$ANALYZER_SRC" checkout --detach "$ANALYZER_COMMIT"

cmake -S "$ANALYZER_SRC" -B "$ANALYZER_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    > "$RUN_DIR/analyzer-configure.log" 2>&1
cmake --build "$ANALYZER_BUILD" --parallel 4 \
    > "$RUN_DIR/analyzer-build.log" 2>&1

ANALYZER="$ANALYZER_BUILD/ClangBuildAnalyzer"

{
    echo "Run ID: ${RUN_ID}"
    echo "Docker image: ${IMAGE}@${DIGEST}"
    echo "Clang: $(clang++-14 --version | head -n 1)"
    echo "Clang Build Analyzer commit: ${ANALYZER_COMMIT}"
    echo "Repeats per configuration: ${REPEATS}"
    echo "Build type: Release"
    echo "Generator: Ninja"
    echo "Compiler flags: -ftime-trace"
    echo "ccache: disabled"
} > "$RUN_DIR/environment.txt"

for MODE in NONE COMPONENT TWO_HEADERS; do
    case "$MODE" in
        NONE)       LABEL="baseline" ;;
        COMPONENT)  LABEL="pch-component" ;;
        TWO_HEADERS) LABEL="pch-two-headers" ;;
    esac

    for ((i = 1; i <= REPEATS; i++)); do
        BUILD_DIR="$SERVICE_DIR/build-repro-${RUN_ID}-${MODE,,}-${i}"
        RESULT_DIR="$RUN_DIR/$LABEL/run-$i"
        mkdir -p "$RESULT_DIR"

        echo
        echo "=== ${LABEL}, run ${i}/${REPEATS} ==="

        if ! cmake -S "$SERVICE_DIR" -B "$BUILD_DIR" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_COMPILER=/usr/bin/clang++-14 \
            -DCMAKE_CXX_FLAGS=-ftime-trace \
            -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
            -DUSERVER_FEATURE_GRPC=ON \
            -DUSERVER_FEATURE_MONGODB=ON \
            -DUSERVER_FEATURE_POSTGRESQL=ON \
            -DPCH_MODE="$MODE" \
            > "$RESULT_DIR/configure.log" 2>&1; then
            echo "CMake configuration failed; see $RESULT_DIR/configure.log" >&2
            tail -n 60 "$RESULT_DIR/configure.log" >&2
            exit 1
        fi

        "$ANALYZER" --start "$BUILD_DIR" \
            > "$RESULT_DIR/analyzer-start.log" 2>&1

        if ! /usr/bin/time -f '%e' \
            -o "$RESULT_DIR/wall-seconds.txt" \
            cmake --build "$BUILD_DIR" --parallel 4 \
            > "$RESULT_DIR/build.log" 2>&1; then
            echo "Build failed; see $RESULT_DIR/build.log" >&2
            tail -n 60 "$RESULT_DIR/build.log" >&2
            exit 1
        fi

        "$ANALYZER" --stop "$BUILD_DIR" "$RESULT_DIR/trace.bin" \
            > "$RESULT_DIR/analyzer-stop.log" 2>&1
        "$ANALYZER" --analyze "$RESULT_DIR/trace.bin" \
            > "$RESULT_DIR/report.txt"

        echo "Wall-clock build time: $(cat "$RESULT_DIR/wall-seconds.txt") s"
        grep -E 'Compilation \(|Parsing \(frontend\)|Codegen & opts \(backend\)' \
            "$RESULT_DIR/report.txt" || true
    done
done

echo
echo "All experiments finished."
echo "Results: $RUN_DIR"
