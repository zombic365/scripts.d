#!/bin/bash

# Reset
Color_Off="\033[0m"       # Text Reset

# Regular Colors
Black="\033[0;30m"        # Black
Red="\033[0;31m"          # Red
Green="\033[0;32m"        # Green
Yellow="\033[0;33m"       # Yellow
Blue="\033[0;34m"         # Blue
Purple="\033[0;35m"       # Purple
Cyan="\033[0;36m"         # Cyan
White="\033[0;37m"        # White

# Bold
BBlack="\033[1;30m"       # Black
BRed="\033[1;31m"         # Red
BGreen="\033[1;32m"       # Green
BYellow="\033[1;33m"      # Yellow
BBlue="\033[1;34m"        # Blue
BPurple="\033[1;35m"      # Purple
BCyan="\033[1;36m"        # Cyan
BWhite="\033[1;37m"       # White

##### Common function
TODAY=$(date +%y%m%d_%H%M%S)
function Logging() {
    _CMD_LOG="tee -a ./script_${TODAY}.log"
    _RUN_TODAY=$(date "+%y%m%d")
    _RUN_TIME=$(date "+%H:%M:%S.%3N")
  
    _LOG_TIME="${BWhite}[ ${_RUN_TODAY} ${_RUN_TIME} ]${Color_Off}"
    _LOG_TYPE=$1
    _LOG_MSG=$2

    case ${_LOG_TYPE} in
        "CMD")   printf "${_LOG_TIME} ${BWhite}[${_LOG_TYPE}] ${_LOG_MSG}${Color_Off}: "         |eval "${_CMD_LOG}" ;;
        "OK")    printf "${BGreen}${_LOG_TYPE}${Color_Off}\n"                                    |eval "${_CMD_LOG}" ;;        
        "FAIL")  printf "${BRed}${_LOG_TYPE}${Color_Off}\n"                                      |eval "${_CMD_LOG}" ;;
        "SKIP")  printf "${BPurple}${_LOG_TYPE} ${BWhite}-> ${_LOG_MSG}${Color_Off}\n"           |eval "${_CMD_LOG}" ;;
        "WARR")  printf "${_LOG_TIME} ${BCyan}[${_LOG_TYPE}] ${_LOG_MSG}${Color_Off}\n"          |eval "${_CMD_LOG}" ;;
        "INFO")  printf "${_LOG_TIME} ${BWhite}[${_LOG_TYPE}] ${_LOG_MSG}${Color_Off}\n"        |eval "${_CMD_LOG}" ;;
        "CRT")   printf "${_LOG_TIME} ${BWhite}[${_LOG_TYPE}] ${BRed}${_LOG_MSG}${Color_Off}\n"  |eval "${_CMD_LOG}" ;;
    esac
}

function RunCmd() {
    _CMD=$@
    printf "CMD: [ ${_CMD} ]\n" >>./script_cmd_${TODAY}.log 2>&1
    Logging "CMD" "$@"
    
    eval "${_CMD}" >>./script_cmd_${TODAY}.log 2>&1
    if [ $? -eq 0 ]; then
        Logging "OK"
        return 0
    else
        Logging "FAIL"
        return 1
    fi
}
function help_usage() {
    cat <<EOF
Usage: $0 [Options]
Options:
-i, --install   : Install docker
-r, --remove    : Renive docker
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options irh \
    --longoptions install,remove,help \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"

    while true; do
        case "$1" in
            -i | --install)
                pre_install_docker
                if [ $? -eq 0 ]; then
                    install_docker
                else
                    Logging "CRT" "Install docker check fail"
                    exit 1
                fi
            ;;
            -r | --remove) remove_docker ; exit 0 ;;
            -h | --help) help_usage ;;
            --) shift ; break ;;
            *) help_usage ;;
        esac
    done
    
    ### 남아 있는 인자를 얻기 위해 shift 한다.
    shift $((OPTIND-1))
}

function pre_cmd_check() {
    _check_cmd=("curl" "add-apt-repository" "apt-key")
    _check_cmd_fail=()

    for((i=0; i<=${#_check_cmd[@]}; i++)); do
        RunCmd "apt list --installed ${_pkg} |grep -q installed"
        if [ $? -eq 1 ]; then
            _check_cmd_fail+=${_pkg}
        fi
    done

    if [ -n ${_check_cmd_fail} ]; then
        Logging "CRT" "Please check Command, Packages [ ${_check_cmd_fail[@]} ]"
        return 1
    else
        return 0
    fi
}
function pre_pkg_check() {
    _check_pkg=(curl)
    _check_pkg_fail=()

    for((i=0; i<=${#_check_pkg[@]}; i++)); do
        RunCmd "apt list --installed ${_pkg} |grep -q installed"
        if [ $? -eq 1 ]; then
            _check_pkg_fail+=${_pkg}
        fi
    done

    if [ -n ${_check_pkg_fail} ]; then
        Logging "CRT" "Please check Command, Packages [ ${_check_pkg_fail[@]} ]"
        return 1
    else
        return 0
    fi
}

function pre_install_docker() {
##### Docker GPG key add for ubuntu
    # RunCmd "apt-get install -y ca-certificates curl"
    if [ -f /etc/apt/keyrings/docker.asc ]; then
        Logging "SKIP" "Already added GPG key"        
    else
        RunCmd "install -m 0755 -d /etc/apt/keyrings"
        RunCmd "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
        RunCmd "chmod a+r /etc/apt/keyrings/docker.asc"
    fi
    ##### Docker repository add for ubuntu
    RunCmd  "cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu
$(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF"
    RunCmd "apt-get update"
}

function install_docker() {
    for _pkg in "docker-ce" "docker-ce-cli" "containerd.io"; do
        RunCmd "apt install -y ${_pkg}"
    done
}

function remove_docker() {
    for _pkg in "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin" "docker-ce-rootless-extras"; do
        RunCmd "apt purge -y ${_pkg}"
    done

    RunCmd "rm -f /etc/apt/keyrings/docker.asc"
    RunCmd "rm -f /etc/apt/sources.list.d/docker.list"
    RunCmd "rm -rf /var/lib/docker"
    RunCmd "rm -rf /var/lib/containerd"
}

main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"
}
main $*