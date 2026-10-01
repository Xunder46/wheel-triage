#!/usr/bin/env bash
# Runs a GitHub Copilot CLI custom agent (.github/agents/<agent>.agent.md) in the background, waits for it to finish, and prints a
# compact summary for the governing Claude Code session. Claude reads the summary, not the full log.
#
# Usage (from the repo root):
#   bash .claude/scripts/run-agent.sh start <agent> <prompt-file> [model]
#   bash .claude/scripts/run-agent.sh wait  <RUN_ID>
#   bash .claude/scripts/run-agent.sh stop  <RUN_ID>
#
# Each run gets .work/runs/<RUN_ID>/ with the full log, exit code, and a git-status snapshot.
# Written for the bash 3.2 that ships with macOS; no Homebrew tools required.
set -euo pipefail

# ---- Settings ---------------------------------------------------------------------------------
# Keep WAIT_MINUTES below Claude Code's Bash timeout so every call returns on its own.
WAIT_MINUTES="${WAIT_MINUTES:-50}"
TAIL_LINES=40
POLL_SECONDS=15
# Tool permissions come ONLY from .github/copilot/permissions/common.flags + <agent>.flags. The runner
# never passes --allow-all-tools, refuses to run an agent with no profile, and refuses any profile that
# grants everything or lets an interpreter run arbitrary code. Agents are the Copilot editions in
# .github/agents/<agent>.agent.md (they take precedence over .claude/agents/ in Copilot).
PERM_FLAGS=()
load_permissions() {
  local agent="$1" file line dir
  dir="$(git rev-parse --show-toplevel)/.github/copilot/permissions"
  PERM_FLAGS=()
  for file in "$dir/common.flags" "$dir/$agent.flags"; do
    [[ -f $file ]] || { echo "No permission profile: .github/copilot/permissions/$(basename "$file") — refusing to run '$agent'." >&2; exit 2; }
    while IFS= read -r line || [[ -n $line ]]; do
      line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [[ -z $line || $line == \#* ]] && continue
      case "$line" in
        --allow-all-tools*|--allow-all|--allow-all=*|--yolo*|--allow-all-paths*|--allow-all-urls*)
          echo "Refusing to run: $(basename "$file") grants everything ($line). Grant tools one by one." >&2; exit 2 ;;
        *"shell(bash"*|*"shell(sh"*|*"shell(zsh"*|*"shell(fish"*|*"shell(pwsh"*|*"shell(powershell"*|*"shell(cmd"*|\
        *"shell(python"*|*"shell(node"*|*"shell(perl"*|*"shell(ruby"*|*"shell(env"*|*"shell(xargs"*|*"shell(eval"*|*"shell(exec"*)
          case "$line" in --deny-tool=*) ;; *)
            echo "Refusing to run: $(basename "$file") allows an interpreter ($line). Add a gateway check instead." >&2; exit 2 ;;
          esac ;;
        --*) ;;
        *) echo "Refusing to run: $(basename "$file") has a line that is not a flag: $line" >&2; exit 2 ;;
      esac
      PERM_FLAGS+=("$line")
    done < "$file"
  done
}
# Wrapper each Copilot run goes through. with-opencode.sh adds the session header OpenCode Go needs.
# Set to "" to call copilot directly (for providers that don't need it).
COPILOT_WRAPPER="with-opencode.sh"
# -----------------------------------------------------------------------------------------------

ORIG_PWD="$PWD"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
RUNS="$REPO_ROOT/.work/runs"
mkdir -p "$RUNS"

usage() {
  sed -n '5,8p' "$SCRIPT" >&2
  exit 2
}

status_lines() { git -c core.quotepath=off status --porcelain=v1 -uall; }

run_dir_for() {
  local dir="$RUNS/$1"
  if [[ ! -d $dir ]]; then echo "Unknown run id: $1" >&2; exit 2; fi
  echo "$dir"
}

worker_alive() {
  local pid_file="$1/pid"
  [[ -f $pid_file ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null
}

worker() {
  # Runs in the detached background process.
  local dir="$1" agent prompt_file model code
  agent="$(cat "$dir/agent")"
  prompt_file="$(cat "$dir/prompt_file")"
  model="$(cat "$dir/model")"
  local prompt="Your task brief is in the file ${prompt_file}. Read the whole file and carry it out. You cannot ask the user questions in this run. If something is unclear, make the most reasonable choice and list each such choice under an Open questions heading at the end of your final response."
  load_permissions "$agent"
  local args=(-p "$prompt" --agent "$agent" --no-ask-user "${PERM_FLAGS[@]}")
  if [[ -n $model ]]; then args+=(--model "$model"); fi
  export OPENCODE_SESSION="copilot-$(basename "$dir")"   # one stable session per run
  set +e
  if [[ -n $COPILOT_WRAPPER ]]; then
    bash "$(dirname "$SCRIPT")/$COPILOT_WRAPPER" copilot "${args[@]}" > "$dir/output.log" 2>&1 < /dev/null
  else
    copilot "${args[@]}" > "$dir/output.log" 2>&1 < /dev/null
  fi
  code=$?
  set -e
  echo "$code" > "$dir/exit"
}

start_run() {
  local agent="$1" prompt_file="$2" model="${3:-}"
  local abs="$prompt_file"
  if [[ $abs != /* ]]; then abs="$ORIG_PWD/$prompt_file"; fi
  if [[ ! -f $abs ]]; then echo "Prompt file not found: $prompt_file" >&2; exit 2; fi
  abs="$(cd "$(dirname "$abs")" && pwd)/$(basename "$abs")"
  local rel="${abs#"$REPO_ROOT"/}"

  if [[ ! -f $REPO_ROOT/.github/agents/$agent.agent.md ]]; then
    echo "No Copilot agent .github/agents/$agent.agent.md — refusing to run (the .claude/ edition has no Copilot permissions)." >&2
    exit 2
  fi
  load_permissions "$agent"   # validate now, so a bad profile fails before anything starts

  local id dir
  id="$(date +%Y%m%d-%H%M%S)-$(printf '%s' "$agent" | tr -cd 'A-Za-z0-9_-')"
  dir="$RUNS/$id"
  mkdir -p "$dir"
  printf '%s' "$agent" > "$dir/agent"
  printf '%s' "$rel" > "$dir/prompt_file"
  printf '%s' "$model" > "$dir/model"
  status_lines > "$dir/before"
  date +%s > "$dir/started_epoch"
  touch "$dir/started"
  echo "$id" > "$RUNS/latest.txt"

  nohup bash "$SCRIPT" __worker "$dir" > /dev/null 2>&1 &
  echo $! > "$dir/pid"
  echo "$id"
}

summary() {
  local id="$1" dir status code="" now started elapsed
  dir="$(run_dir_for "$id")"
  now="$(date +%s)"
  started="$(cat "$dir/started_epoch")"
  elapsed="$(awk -v s="$started" -v n="$now" 'BEGIN { printf "%.1f", (n - s) / 60 }')"

  if [[ -f $dir/exit ]]; then
    code="$(cat "$dir/exit")"
    case "$code" in
      0) status=DONE ;;
      stopped) status=STOPPED ;;
      *) status=FAILED ;;
    esac
  elif worker_alive "$dir"; then
    status=RUNNING
  else
    status=FAILED
    code="none (worker exited without recording an exit code)"
  fi

  echo "RUN_ID: $id"
  echo "AGENT: $(cat "$dir/agent")"
  echo "STATUS: $status"
  if [[ -n $code ]]; then echo "EXIT_CODE: $code"; fi
  echo "ELAPSED_MIN: $elapsed"
  echo "LOG: .work/runs/$id/output.log"

  if [[ $status == RUNNING ]]; then
    echo "NEXT: still running. Call again with: wait $id"
    return 0
  fi

  # Files the run created or touched, ignoring .work/ and anything already dirty and untouched.
  echo "FILES_CHANGED_DURING_RUN:"
  local any=0 line path
  while IFS= read -r line; do
    if [[ -z $line ]]; then continue; fi
    path="${line:3}"
    if [[ $path == *" -> "* ]]; then path="${path##* -> }"; fi
    path="${path#\"}"; path="${path%\"}"
    if [[ $path == .work/* ]]; then continue; fi
    if ! grep -qxF -- "$line" "$dir/before" || { [[ -e $path ]] && [[ $path -nt $dir/started ]]; }; then
      echo "  $line"
      any=1
    fi
  done < <(status_lines)
  if [[ $any -eq 0 ]]; then echo "  (none)"; fi

  echo "--- LOG TAIL (last $TAIL_LINES lines) ---"
  if [[ -f $dir/output.log ]]; then tail -n "$TAIL_LINES" "$dir/output.log"; else echo "(no log written)"; fi
}

wait_run() {
  local id="$1" dir deadline
  dir="$(run_dir_for "$id")"
  deadline=$(( $(date +%s) + WAIT_MINUTES * 60 ))
  while [[ ! -f $dir/exit ]] && [[ $(date +%s) -lt $deadline ]]; do
    if ! worker_alive "$dir"; then
      sleep 2   # let the worker finish writing its exit code
      break
    fi
    sleep "$POLL_SECONDS"
  done
  summary "$id"
}

descendants() {
  local p
  for p in $(pgrep -P "$1" || true); do
    echo "$p"
    descendants "$p"
  done
}

stop_run() {
  local id="$1" dir wpid tree
  dir="$(run_dir_for "$id")"
  if worker_alive "$dir"; then
    wpid="$(cat "$dir/pid")"
    tree="$(descendants "$wpid")"   # collect the whole tree before anything is re-parented
    kill -TERM "$wpid" 2>/dev/null || true
    if [[ -n $tree ]]; then kill -TERM $tree 2>/dev/null || true; fi
    sleep 1
  fi
  echo stopped > "$dir/exit"
  summary "$id"
}

cmd="${1:-}"
if [[ $# -gt 0 ]]; then shift; fi
case "$cmd" in
  start)    if [[ $# -lt 2 ]]; then usage; fi; id="$(start_run "$@")"; wait_run "$id" ;;
  wait)     if [[ $# -ne 1 ]]; then usage; fi; wait_run "$1" ;;
  stop)     if [[ $# -ne 1 ]]; then usage; fi; stop_run "$1" ;;
  __worker) worker "$1" ;;
  *)        usage ;;
esac
