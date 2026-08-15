#!/usr/bin/env bash
#
# Run any flutter command with config injected from the 1Password-backed `.env`.
#
#   tool/dev.sh run
#   tool/dev.sh run -d "iPhone 17 Pro Max"
#   tool/dev.sh build apk --debug
#
# Why this exists: 1Password's local-env-file integration exposes `.env` as a
# named pipe (FIFO), not a regular file. Flutter's `--dart-define-from-file`
# gates on `File.existsSync()`, which is false for a FIFO — so it bails with
# "Did not find the file passed to --dart-define-from-file" without ever reading
# it. This reads the pipe itself and expands each line into a `--dart-define`,
# so the secrets go straight from 1Password into the build with no plaintext
# copy on disk.
#
# Trade-off: the values land in this process's argument list, so they are
# visible via `ps` to processes running as you. That is the price of
# `--dart-define`; there is no env-var channel for compile-time defines. It is
# still a smaller exposure than a plaintext file that outlives the build.
set -euo pipefail

ENV_PIPE="${ENV_PIPE:-.env}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

if [[ ! -e "$ENV_PIPE" ]]; then
  echo "tool/dev.sh: '$ENV_PIPE' not found — is the 1Password environment linked?" >&2
  exit 1
fi

defines=()
keys=()
# `read` on a FIFO opens it once and reads to EOF; 1Password re-serves it on
# each open, so this is safe to run repeatedly. The `|| [[ -n $line ]]` keeps a
# final line that has no trailing newline.
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"   # strip leading whitespace
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" != *=* ]] && continue

  key="${line%%=*}"
  val="${line#*=}"
  # Tolerate quoted values; 1Password currently emits bare ones.
  if [[ "$val" == \"*\" || "$val" == \'*\' ]]; then
    val="${val:1:${#val}-2}"
  fi

  defines+=( "--dart-define=${key}=${val}" )
  keys+=( "$key" )
done < "$ENV_PIPE"

if [[ ${#defines[@]} -eq 0 ]]; then
  echo "tool/dev.sh: read 0 variables from '$ENV_PIPE' — is 1Password unlocked?" >&2
  exit 1
fi

echo "tool/dev.sh: injecting ${#defines[@]} defines from '$ENV_PIPE' (${keys[*]})" >&2
exec "$FLUTTER_BIN" "$@" "${defines[@]}"
