#!/usr/bin/env bash
# ===========================================================================
# Agentic Learning Series Demo — Installer
# ===========================================================================
# Sets up two NemoClaw sandboxes (data-pipeline + reporter) from scratch:
#   1. Checks prerequisites (openshell, nemoclaw, hermes)
#   2. Creates both sandboxes via nemoclaw onboard
#   3. Applies YAML network policies
#   4. Uploads scripts, skills, data and AGENTS.md to each sandbox
#   5. Installs Python dependencies inside each sandbox
#   6. Sets up local Hermes profiles
#   7. Verifies everything is ready
#
# Usage:
#   bash install.sh              # full setup
#   bash install.sh --dry-run    # show commands without running
# ===========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}  ▸ $1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()  { echo -e "${RED}  ✗ $1${NC}"; exit 1; }
section() { echo -e "\n${CYAN}═══════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}═══════════════════════════════════════${NC}"; }

DRY_RUN="${DRY_RUN:-0}"

PIPELINE_SB="data-pipeline"
REPORTER_SB="reporter"

for arg in "$@"; do
    case "$arg" in
        --dry-run)      DRY_RUN=1 ;;
    esac
done

if [[ "$DRY_RUN" == "1" ]]; then
    echo -e "${YELLOW}DRY RUN MODE — commands shown but not executed${NC}"
fi

echo ""
echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}  ║  Agentic Learning Series Demo Installer                              ║${NC}"
echo -e "${CYAN}  ║  Multi-agent ML pipeline with NemoClaw security         ║${NC}"
echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Check prerequisites ───────────────────────────────────────────
section "1. Checking prerequisites"

info "Checking required binaries..."
command -v openshell >/dev/null 2>&1 || fail "openshell CLI not found. Is NemoClaw installed?"
command -v nemoclaw >/dev/null 2>&1 || fail "nemoclaw CLI not found. Is NemoClaw installed?"
command -v hermes >/dev/null 2>&1 || fail "hermes CLI not found. Is Hermes installed?"
ok "All binaries found"

# Verify required repo files exist
REQUIRED_FILES=(
    "data/raw/telco-churn.csv"
    "scripts/prepare.py"
    "scripts/train.py"
    "scripts/render_report.py"
    "scripts/demo-security.sh"
    "skills/preprocessor/SKILL.md"
    "skills/architect/SKILL.md"
    "skills/trainer/SKILL.md"
    "skills/reporter/SKILL.md"
    "AGENTS.md"
    "policy/demo-pipeline-restricted.yaml"
    "policy/reporter-restricted.yaml"
    "requirements.txt"
)

for rf in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$rf" ]]; then
        fail "Required file missing: $rf"
    fi
done
ok "All required files present"

# ── Step 2: Ensure gateway is running ─────────────────────────────────────
section "2. Checking OpenShell gateway"

if openshell gateway status >/dev/null 2>&1; then
    ok "Gateway already running"
else
    info "Gateway not running — it will be started automatically by 'nemoclaw onboard'"
    warn "If port 8080 is in use, stop the conflicting container first:"
    warn "  docker stop openshell-cluster-nemoclaw"
fi

# ── Step 3: Create data-pipeline sandbox ──────────────────────────────────
section "3. Creating $PIPELINE_SB sandbox"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [DRY RUN] nemoclaw onboard --name $PIPELINE_SB"
    echo "  [DRY RUN] (wizard: agent=hermes, model=nvidia/nemotron-3-super-120b-a12b, provider=nvidia-prod)"
else
    if ! [[ -t 0 ]]; then
        warn "No TTY detected — cannot run interactive wizard"
        info "Run manually: nemoclaw onboard --name $PIPELINE_SB"
        exit 1
    fi
    info "Running interactive wizard..."
    info "  When prompted: agent=hermes, model=nvidia/nemotron-3-super-120b-a12b, provider=nvidia-prod"
    echo ""
    nemoclaw onboard --name "$PIPELINE_SB"
fi
ok "$PIPELINE_SB sandbox created"

# ── Step 4: Create reporter sandbox ───────────────────────────────────────
section "4. Creating $REPORTER_SB sandbox"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [DRY RUN] nemoclaw onboard --name $REPORTER_SB"
else
    if ! [[ -t 0 ]]; then
        warn "No TTY detected — cannot run interactive wizard"
        exit 1
    fi
    info "Running interactive wizard..."
    info "  When prompted: agent=hermes, model=nvidia/nemotron-3-super-120b-a12b, provider=nvidia-prod"
    echo ""
    nemoclaw onboard --name "$REPORTER_SB"
fi
ok "$REPORTER_SB sandbox created"

# ── Step 5: Apply network policies ────────────────────────────────────────
section "5. Applying network policies"

info "Removing default presets from $PIPELINE_SB..."
if [[ "$DRY_RUN" == "0" ]]; then
    for preset in npm pypi huggingface brew brave github; do
        echo '' | nemoclaw "$PIPELINE_SB" policy-remove --yes 2>/dev/null <<< "$preset" || true
    done
fi

info "Applying policy: demo-pipeline-restricted.yaml"
if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [DRY RUN] openshell policy set --policy policy/demo-pipeline-restricted.yaml $PIPELINE_SB --wait"
else
    openshell policy set --policy "$SCRIPT_DIR/policy/demo-pipeline-restricted.yaml" "$PIPELINE_SB" --wait
fi
ok "$PIPELINE_SB policy applied (NVIDIA inference + local gateway only)"

info "Removing default presets from $REPORTER_SB..."
if [[ "$DRY_RUN" == "0" ]]; then
    for preset in npm pypi huggingface brew brave github; do
        echo '' | nemoclaw "$REPORTER_SB" policy-remove --yes 2>/dev/null <<< "$preset" || true
    done
fi

info "Applying policy: reporter-restricted.yaml"
if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [DRY RUN] openshell policy set --policy policy/reporter-restricted.yaml $REPORTER_SB --wait"
else
    openshell policy set --policy "$SCRIPT_DIR/policy/reporter-restricted.yaml" "$REPORTER_SB" --wait
fi
ok "$REPORTER_SB policy applied (ZERO network)"

# ── Step 6: Upload files to data-pipeline ─────────────────────────────────
section "6. Uploading files to $PIPELINE_SB"

UPLOAD_PIPE=(
    "data/raw/telco-churn.csv:/sandbox/data/raw/telco-churn.csv"
    "scripts/prepare.py:/sandbox/scripts/prepare.py"
    "scripts/train.py:/sandbox/scripts/train.py"
    "scripts/render_report.py:/sandbox/scripts/render_report.py"
    "scripts/demo-security.sh:/sandbox/scripts/demo-security.sh"
    "AGENTS.md:/sandbox/AGENTS.md"
    "requirements.txt:/sandbox/requirements.txt"
    "skills/preprocessor/SKILL.md:/sandbox/skills/preprocessor/SKILL.md"
    "skills/architect/SKILL.md:/sandbox/skills/architect/SKILL.md"
    "skills/trainer/SKILL.md:/sandbox/skills/trainer/SKILL.md"
)

for upload in "${UPLOAD_PIPE[@]}"; do
    local_src="${upload%%:*}"
    remote_dst="${upload##*:}"
    info "Uploading $local_src -> $remote_dst"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "  [DRY RUN] openshell sandbox upload $PIPELINE_SB $local_src $remote_dst"
    else
        openshell sandbox upload "$PIPELINE_SB" "$SCRIPT_DIR/$local_src" "$remote_dst"
    fi
done

info "Installing Python dependencies in $PIPELINE_SB..."
if [[ "$DRY_RUN" == "0" ]]; then
    openshell sandbox exec -n "$PIPELINE_SB" bash -c 'python3 -m venv /sandbox/.venv && /sandbox/.venv/bin/pip install -r /sandbox/requirements.txt'
fi
ok "Python deps installed in $PIPELINE_SB"

# ── Step 7: Upload files to reporter ──────────────────────────────────────
section "7. Uploading files to $REPORTER_SB"

UPLOAD_RPT=(
    "scripts/render_report.py:/sandbox/scripts/render_report.py"
    "AGENTS.md:/sandbox/AGENTS.md"
    "requirements.txt:/sandbox/requirements.txt"
    "skills/reporter/SKILL.md:/sandbox/skills/reporter/SKILL.md"
)

for upload in "${UPLOAD_RPT[@]}"; do
    local_src="${upload%%:*}"
    remote_dst="${upload##*:}"
    info "Uploading $local_src -> $remote_dst"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "  [DRY RUN] openshell sandbox upload $REPORTER_SB $local_src $remote_dst"
    else
        openshell sandbox upload "$REPORTER_SB" "$SCRIPT_DIR/$local_src" "$remote_dst"
    fi
done

info "Installing Python dependencies in $REPORTER_SB..."
if [[ "$DRY_RUN" == "0" ]]; then
    openshell sandbox exec -n "$REPORTER_SB" bash -c 'python3 -m venv /sandbox/.venv && /sandbox/.venv/bin/pip install -r /sandbox/requirements.txt'
fi
ok "Python deps installed in $REPORTER_SB"

# ── Step 8: Setup local Hermes profiles ───────────────────────────────────
section "8. Setting up local Hermes profiles"

info "Running setup_profiles.sh..."
if [[ "$DRY_RUN" == "1" ]]; then
    echo "  [DRY RUN] bash scripts/setup_profiles.sh"
else
    bash "$SCRIPT_DIR/scripts/setup_profiles.sh"
fi
ok "Hermes profiles configured"

# ── Step 9: Verify ────────────────────────────────────────────────────────
section "9. Verification"

if [[ "$DRY_RUN" == "0" ]]; then
    info "Sandbox status:"
    nemoclaw list
    echo ""

    info "$PIPELINE_SB policy:"
    openshell policy get "$PIPELINE_SB" 2>&1 | grep "Active:" || true

    info "$REPORTER_SB policy:"
    openshell policy get "$REPORTER_SB" 2>&1 | grep "Active:" || true
    echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║  Installation complete!                                 ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Sandboxes:"
echo "    data-pipeline    → NVIDIA inference only (blocked: everything else)"
echo "    reporter         → ZERO network (completely blocked)"
echo ""
echo "  Next steps:"
echo "    1. Activate the venv: source .venv/bin/activate"
echo "    2. Run the pipeline: bash scripts/run_pipeline.sh data/raw/telco-churn.csv Churn"
echo "    3. Or run step by step (see agentic-learning-demo-guide.md)"
echo "    4. Run security demo: bash scripts/demo-security.sh"
echo ""
echo "  Architecture diagram:"
echo "    https://excalidraw.com/#json=Bp6Up7SZu4rN21cpMA5Yo,9etHITeVufwTQLsh_g7Yow"
echo ""
