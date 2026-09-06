#!/usr/bin/env bash
# detect-context.sh -- the deterministic half of harness:ai-context Step 2.
#
# Prints key=value lines on stdout and exits 1 when no context file exists.
# Field meanings and the resolution matrix the agent applies to this output:
# ../references/target-resolution.md
#
# Usage: detect-context.sh [--file PATH] [--type TYPE] [--dir DIR]

set -euo pipefail

dir=.
file=
type=

die() { printf '%s\n' "$*" >&2; exit "${2:-2}"; }

need_value() { [ "$#" -ge 2 ] || die "$1 needs a value"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file) need_value "$@"; file=$2; shift 2 ;;
    --type) need_value "$@"; type=$2; shift 2 ;;
    --dir)  need_value "$@"; dir=$2;  shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

kind_of() {
  case "$(basename -- "$1")" in
    CLAUDE.md) printf claude ;;
    AGENTS.md) printf agents ;;
    GEMINI.md) printf gemini ;;
    *)         printf unknown ;;
  esac
}

# True when the whole body is a single `@other.md` import -- an alias for
# another context file, not a second source. Prints the imported name.
import_target() {
  local body
  body=$(grep -vE '^[[:space:]]*(#.*)?$' -- "$1" || true)
  case "$body" in
    @*.md) printf '%s' "${body#@}" ;;
    *) return 1 ;;
  esac
}

candidates=()
if [ -n "$file" ]; then
  [ -e "$file" ] || die "not found: $file" 1
  candidates=("$file")
else
  for name in CLAUDE.md AGENTS.md GEMINI.md; do
    if [ -e "$dir/$name" ]; then candidates+=("$dir/$name"); fi
  done
fi
[ "${#candidates[@]}" -gt 0 ] || die "no AI context file found in $dir" 1

primary=${candidates[0]}
primary_real=$(readlink -f -- "$primary")
primary_import=$(import_target "$primary" || true)

# Collapse aliases: same inode, or one file is only an import of the other.
others=()
aliases=()
for c in "${candidates[@]:1}"; do
  c_base=$(basename -- "$c")
  c_import=$(import_target "$c" || true)
  if [ "$(readlink -f -- "$c")" = "$primary_real" ] \
     || [ "$primary_import" = "$c_base" ] \
     || [ "$c_import" = "$(basename -- "$primary")" ]; then
    aliases+=("$c")
  else
    others+=("$c")
  fi
done

# The text a reader actually gets: follow a one-line import to its target.
content_path=$primary_real
if [ -n "$primary_import" ] && [ -e "$(dirname -- "$primary")/$primary_import" ]; then
  content_path=$(readlink -f -- "$(dirname -- "$primary")/$primary_import")
fi

[ -n "$type" ] || type=$(kind_of "$primary")

line_count=$(wc -l < "$content_path" | tr -d ' ')
if   [ "$line_count" -le 400 ]; then c7=PASS
elif [ "$line_count" -le 500 ]; then c7=WARN
else c7=FAIL
fi

# Sizing heuristics: references/templates/README.md.
if [ "$type" = claude ]; then
  agents=$({ find "$dir/.claude/agents" -maxdepth 1 -name '*.md' 2>/dev/null || true; } | wc -l | tr -d ' ')
  if   [ "$agents" -le 2 ]; then size_class=simple
  elif [ "$agents" -le 6 ]; then size_class=standard
  else size_class=large
  fi
else
  files=$({ git -C "$dir" ls-files 2>/dev/null || true; } | wc -l | tr -d ' ')
  if [ "$files" -eq 0 ]; then
    files=$({ find "$dir" -type f -not -path '*/.git/*' 2>/dev/null || true; } | wc -l | tr -d ' ')
  fi
  if   [ "$files" -lt 20 ];  then size_class=small
  elif [ "$files" -le 100 ]; then size_class=medium
  else size_class=large
  fi
fi

join() { local IFS=,; printf '%s' "$*"; }

printf 'path=%s\n'             "$primary"
printf 'kind=%s\n'             "$type"
printf 'content_path=%s\n'     "$content_path"
printf 'symlink_target=%s\n'   "$(readlink -- "$primary" || true)"
printf 'aliases=%s\n'          "$(join "${aliases[@]+"${aliases[@]}"}")"
printf 'other_candidates=%s\n' "$(join "${others[@]+"${others[@]}"}")"
printf 'line_count=%s\n'       "$line_count"
printf 'c7=%s\n'               "$c7"
printf 'size_class=%s\n'       "$size_class"
