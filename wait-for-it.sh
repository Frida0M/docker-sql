#!/usr/bin/env bash
# wait-for-it.sh

TIMEOUT=15
QUIET=0
PROTOCOL=tcp
VERBOSE=0

echoerr() {
  if [[ $QUIET -ne 1 ]]; then printf "%s\n" "$*" 1>&2; fi
}

usage() {
  exitcode="$1"
  cat << USAGE >&2
Usage:
  $0 host:port [-s] [-t timeout] [-- command args]
  -h HOST | --host=HOST       Host or IP under test
  -p PORT | --port=PORT       TCP port under test
                              Alternatively, you specify the host and port as host:port
  -s | --strict               Only execute subcommand if the test succeeds
  -q | --quiet                Don't output any status messages
  -t TIMEOUT | --timeout=TIMEOUT
                              Timeout in seconds, zero for no timeout
  -- COMMAND ARGS             Execute command with args after the test finishes
USAGE
  exit "$exitcode"
}

wait_for() {
  if [[ $TIMEOUT -gt 0 ]]; then
    echoerr "$host:$port - waiting $TIMEOUT seconds for $PROTOCOL connection"
  else
    echoerr "$host:$port - waiting for $PROTOCOL connection indefinitely"
  fi
  start_ts=$(date +%s)
  while :
  do
    (echo > /dev/$PROTOCOL/$host/$port) >/dev/null 2>&1
    result=$?
    if [[ $result -eq 0 ]]; then
      end_ts=$(date +%s)
      echoerr "$host:$port is available after $((end_ts - start_ts)) seconds"
      break
    fi
    sleep 1
  done
  return $result
}

wait_for_wrapper() {
  # In order to support SIGINT during timeout: http://unix.stackexchange.com/a/57692
  if [[ $QUIET -eq 1 ]]; then
    timeout $busybox_timeout $TIMEOUT $0 --quiet --child --host=$host --port=$port --timeout=$TIMEOUT &
  else
    timeout $busybox_timeout $TIMEOUT $0 --child --host=$host --port=$port --timeout=$TIMEOUT &
  fi
  PID=$!
  trap "kill -INT -$PID" INT
  wait $PID
  RESULT=$?
  if [[ $RESULT -ne 0 ]]; then
    echoerr "$host:$port - timed out after $TIMEOUT seconds"
  fi
  return $RESULT
}

parse_arguments() {
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      *:* )
      host=$(printf "%s\n" "$1"| cut -d : -f 1)
      port=$(printf "%s\n" "$1"| cut -d : -f 2)
      shift 1
      ;;
      --child)
      CHILD=1
      shift 1
      ;;
      -q | --quiet)
      QUIET=1
      shift 1
      ;;
      -s | --strict)
      STRICT=1
      shift 1
      ;;
      -h)
      HOST="$2"
      if [[ $HOST == "" ]]; then break; fi
      shift 2
      ;;
      --host=*)
      HOST="${1#*=}"
      shift 1
      ;;
      -p)
      PORT="$2"
      if [[ $PORT == "" ]]; then break; fi
      shift 2
      ;;
      --port=*)
      PORT="${1#*=}"
      shift 1
      ;;
      -t)
      TIMEOUT="$2"
      if [[ $TIMEOUT == "" ]]; then break; fi
      shift 2
      ;;
      --timeout=*)
      TIMEOUT="${1#*=}"
      shift 1
      ;;
      --)
      shift
      CLI=("$@")
      break
      ;;
      --help)
      usage 0
      ;;
      *)
      echoerr "Unknown argument: $1"
      usage 1
      ;;
    esac
  done

  if [[ "$HOST" == "" || "$PORT" == "" ]]; then
    echoerr "Error: you need to provide a host and port to test."
    usage 2
  fi
}

parse_arguments "$@"

if [[ $CHILD -gt 0 ]]; then
  wait_for
  RESULT=$?
  exit $RESULT
else
  if [[ $TIMEOUT -gt 0 ]]; then
    wait_for_wrapper
    RESULT=$?
  else
    wait_for
    RESULT=$?
  fi
fi

if [[ $CLI != "" ]]; then
  if [[ $RESULT -ne 0 && $STRICT -eq 1 ]]; then
    echoerr "$command failed with exit code $RESULT"
    exit $RESULT
  fi

  exec "${CLI[@]}"
fi

exit $RESULT