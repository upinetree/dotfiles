detect_platform() {
  export PLATFORM
  case "$(uname)" in
    *Darwin*) PLATFORM='osx'     ;;
    *Linux*)  PLATFORM='linux'   ;;
    *)        echo 'Your platform is not supported'
              exit 0 ;;
  esac
}

# log <level> <text>
# level: error, warn, info, success
log() {
  local open="\033["
  local close="${open}0m"
  local red="1;31m"
  local green="1;32m"
  local yellow="1;33m"
  local cyan="1;36m"

  local color="$close"

  if [ "$#" -eq 1 ]; then
    local level=
    local text="$1"
  else
    local level="$1"
    local text="$2"
  fi

  case "$level" in
    error)   color="$red"    ;;
    warn)    color="$yellow" ;;
    info)    color="$cyan"   ;;
    success) color="$green"  ;;
  esac

  echo -e "$open$color$text$close"
}

exists() {
 type "$1" &> /dev/null
}
