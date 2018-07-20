#!/usr/bin/env bash
# ##################################################
#
version="1.0.0"              # Sets version variable
#
# HISTORY:
#
# * DATE - v1.0.0  - First Creation
#  author Daniel Cortes Pichardo
#
# ##################################################

function setupGlobalVariables(){
if [ -z "$path" ]; then
path=$(pwd);
info "Change path using path variable"
fi
info "Running on : $path"
}

function mainScript() {

if $runshell ; then
runShell
fi

if $update ; then
executeCommand "git pull" "Updating"
fi

if $branches ; then
executeCommand "mvn clean install -DskipTests"
fi

if $compile ; then
executeCommand "mvn clean install -DskipTests" "Compiling"
fi

if $init ; then
clone
fi
}

function clone(){
read -p "Are you sure? " -n 1 -r
echo    # move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  cd $path
  git clone git@github.com:kukulkan-project/kukulkan-shell.git
  git clone git@github.com:kukulkan-project/kukulkan-grammar.git
  git clone git@github.com:kukulkan-project/kukulkan-generator-angularjs.git
  git clone git@github.com:kukulkan-project/kukulkan-engine.git
  git clone git@github.com:kukulkan-project/kukulkan-metamodel.git
fi
}



function evalCommand(){
if [[ -z "$3" ]]; then
  MESSAGE=$(git rev-parse --abbrev-ref HEAD);
  info "$2 : $MESSAGE"
else
  info "$2 :: $3"
  eval $1
fi }
function runShell() {
 cd '../kukulkan-shell/kukulkan-shell-terminal/' || exit
 mvn spring-boot:run -DskipTests
}

function executeCommand(){
cd $path
if $compile ; then
PATH_TO_PROCESS='kukulkan-language-server/mx.infotec.dads.kukulkan.dsl.parent/'
CMD_PROCESS="./gradlew install"
else
PATH_TO_PROCESS='kukulkan-language-server/'
CMD_PROCESS="$1"
fi
cd "$PATH_TO_PROCESS" || exit
evalCommand "$CMD_PROCESS" "kukulkan-language-server" $2
if $compile ; then
cd ../
fi 
if [ $? -eq 0 ]; then
    cd '../kukulkan-metamodel/' || exit
    evalCommand "$1" "kukulkan-metamodel" $2
    if [ $? -eq 0 ]; then
        cd '../kukulkan-engine/' || exit
        evalCommand "$1" "kukulkan-engine" $2
        if [ $? -eq 0 ]; then
            cd '../kukulkan-generator-angularjs' || exit
            evalCommand "$1" "kukulkan-generator-angularjs" $2
            if [ $? -eq 0 ]; then
                cd '../kukulkan-shell/' || exit
                evalCommand "$1" "kukulkan-shell" $2
                if [ $? -eq 0 ]; then
                    success "kukulkan project :: $2"
                else
                    error "kukulkan-shell"
                fi
            else
                 error "kukulkan-generator-angularjs"
            fi
        else
            error "kukulkan-engine"
        fi
    else
        error "kukulkan-metamodel"
    fi
else
    error "kukulkan-grammar"
fi
}

function trapCleanup() {
  echo ""
  # Delete temp files, if any
  if [ -d "${tmpDir}" ] ; then
    rm -r "${tmpDir}"
  fi
  die "Exit trapped. In function: '${FUNCNAME[*]}'"
}

function safeExit() {
  # Delete temp files, if any
  if [ -d "${tmpDir}" ] ; then
    rm -r "${tmpDir}"
  fi
  trap - INT TERM EXIT
  exit
}

# Set Base Variables
# ----------------------
scriptName=$(basename "$0")

# Set Flags
quiet=false
printLog=false
verbose=false
force=false
strict=false
debug=false
init=false
branches=false
update=false
compile=false
runshell=false
args=()

# Set Colors
bold=$(tput bold)
reset=$(tput sgr0)
purple=$(tput setaf 171)
red=$(tput setaf 1)
green=$(tput setaf 76)
tan=$(tput setaf 3)
blue=$(tput setaf 38)
underline=$(tput sgr 0 1)

# Set Temp Directory
tmpDir="/tmp/${scriptName}.$RANDOM.$RANDOM.$RANDOM.$$"
(umask 077 && mkdir "${tmpDir}") || {
  die "Could not create temporary directory! Exiting."
}

# Logging
# -----------------------------------
# Log is only used when the '-l' flag is set.
logFile="${HOME}/Library/Logs/${scriptBasename}.log"


# Options and Usage
# -----------------------------------
usage() {
  echo -n "${scriptName} [OPTION]... [FILE]...

This script is used for kukulkan project initial configuration.

 ${bold}Options:${reset}
      --path        Path to kukulkan project
  -i, --init        Download all master projects
  -u, --update      Updating all projects
  -c, --comple      Compiling all projects
  -b, --branches    Show all repository and branches
  -r  --runshell    Run the kukulkan shell
  -h, --help        Display this help and exit
      --version     Output version information and exit
"
}

# Iterate over options breaking -ab into -a -b when needed and --foo=bar into
# --foo bar
optstring=h
unset options
while (($#)); do
  case $1 in
    # If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
        c=${1:i:1}

        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;

    # If option is of type --foo=bar
    --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --) options+=(--endopts) ;;
    # Otherwise, nothing special
    *) options+=("$1") ;;
  esac
  shift
done
set -- "${options[@]}"
unset options

# Print help if no arguments were passed.
# Uncomment to force arguments when invoking the script
# -------------------------------------
[[ $# -eq 0 ]] && set -- "--help"

# Read the options and set stuff
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2; safeExit ;;
    --version) echo "$(basename $0) ${version}"; safeExit ;;
    --path) shift; path=${1} ;;
    -p|--password) shift; echo "Enter Pass: "; stty -echo; read PASS; stty echo;
      echo ;;
    -v|--verbose) verbose=true ;;
    -u|--update) update=true ;;
    -c|--compile) compile=true ;;
    -i|--init) init=true ;;
    -b|--branches) branches=true ;;
    -r|--runshell) runshell=true ;;
    -l|--log) printLog=true ;;
    -q|--quiet) quiet=true ;;
    -s|--strict) strict=true;;
    -d|--debug) debug=true;;
    --force) force=true ;;
    --endopts) shift; break ;;
    *) die "invalid option: '$1'." ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")


# Logging & Feedback
# -----------------------------------------------------
function _alert() {
  if [ "${1}" = "error" ]; then local color="${bold}${red}"; fi
  if [ "${1}" = "warning" ]; then local color="${red}"; fi
  if [ "${1}" = "success" ]; then local color="${green}"; fi
  if [ "${1}" = "debug" ]; then local color="${purple}"; fi
  if [ "${1}" = "header" ]; then local color="${bold}${tan}"; fi
  if [ "${1}" = "input" ]; then local color="${bold}"; fi
  if [ "${1}" = "info" ] || [ "${1}" = "notice" ]; then local color=""; fi
  # Don't use colors on pipes or non-recognized terminals
  if [[ "${TERM}" != "xterm"* ]] || [ -t 1 ]; then color=""; reset=""; fi

  # Print to console when script is not 'quiet'
  if ${quiet}; then return; else
   echo -e "$(date +"%r") ${color}$(printf "[%7s]" "${1}") ${_message}${reset}";
  fi

  # Print to Logfile
  if ${printLog} && [ "${1}" != "input" ]; then
    color=""; reset="" # Don't use colors in logs
    echo -e "$(date +"%m-%d-%Y %r") $(printf "[%7s]" "${1}") ${_message}" >> "${logFile}";
  fi
}

function die ()       { local _message="${*} Exiting."; echo -e "$(_alert error)"; safeExit;}
function error ()     { local _message="${*}"; echo -e "$(_alert error)"; }
function warning ()   { local _message="${*}"; echo -e "$(_alert warning)"; }
function notice ()    { local _message="${*}"; echo -e "$(_alert notice)"; }
function info ()      { local _message="${*}"; echo -e "$(_alert info)"; }
function debug ()     { local _message="${*}"; echo -e "$(_alert debug)"; }
function success ()   { local _message="${*}"; echo -e "$(_alert success)"; }
function input()      { local _message="${*}"; echo -n "$(_alert input)"; }
function header()     { local _message="== ${*} ==  "; echo -e "$(_alert header)"; }
function verbose()    { if ${verbose}; then debug "$@"; fi }


# SEEKING CONFIRMATION
# ------------------------------------------------------
function seek_confirmation() {
  # echo ""
  input "$@"
  if "${force}"; then
    notice "Forcing confirmation with '--force' flag set"
  else
    read -p " (y/n) " -n 1
    echo ""
  fi
}
function is_confirmed() {
  if "${force}"; then
    return 0
  else
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      return 0
    fi
    return 1
  fi
}
function is_not_confirmed() {
  if "${force}"; then
    return 1
  else
    if [[ "${REPLY}" =~ ^[Nn]$ ]]; then
      return 0
    fi
    return 1
  fi
}


# Trap bad exits with your cleanup function
trap trapCleanup EXIT INT TERM

# Set IFS to preferred implementation
IFS=$' \n\t'

# Exit on error. Append '||true' when you run the script if you expect an error.
set -o errexit

# Run in debug mode, if set
if ${debug}; then set -x ; fi

# Exit on empty variable
if ${strict}; then set -o nounset ; fi

# Bash will remember & return the highest exitcode in a chain of pipes.
# This way you can catch the error in case mysqldump fails in `mysqldump |gzip`, for example.
set -o pipefail

# Setting up Global Variables
setupGlobalVariables

# Run your script
mainScript

# Exit cleanly
safeExit
