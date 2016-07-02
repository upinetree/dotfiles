detect_platform() {
  export PLATFORM
  case "$(uname)" in
    *Darwin*) PLATFORM='osx'     ;;
    *Linux*)  PLATFORM='linux'   ;;
    *)        echo 'Your platform is not supported'
              exit 0 ;;
  esac
}
