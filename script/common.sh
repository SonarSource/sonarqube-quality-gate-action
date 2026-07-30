#!/usr/bin/env bash

# Begin Standard 'imports'
set -e
set -o pipefail

gray="\\033[37m"
blue="\\033[36m"
red="\\033[31m"
yellow="\\033[33m"
green="\\033[32m"
reset="\\033[0m"

info() { echo -e "${blue}INFO: $*${reset}"; }
error() { echo -e "${red}ERROR: $*${reset}"; }
debug() {
    if [[ "${DEBUG}" == "true" ]]; then
        echo -e "${gray}DEBUG: $*${reset}";
    fi
}

success() { echo -e "${green}✔ $*${reset}"; }
warn() { echo -e "${yellow}✖ $*${reset}"; exit 1; }
fail() { echo -e "${red}✖ $*${reset}"; exit 1; }

# support old GH Actions runners
set_output () {
  if [[ -n "${GITHUB_OUTPUT}" ]]; then
    echo "${1}=${2}" >> "${GITHUB_OUTPUT}"
  else
    echo "::set-output name=${1}::${2}"
  fi
}

## Enable debug mode.
enable_debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    info "Enabling debug mode."
    set -x
  fi
}

# Execute a command, saving its output and exit status code, and echoing its output upon completion.
# Globals set:
#   status: Exit status of the command that was executed.
#   output: Output generated from the command.
#
run() {
  echo "$@"
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  echo "${output}"
}

# End standard 'imports'

