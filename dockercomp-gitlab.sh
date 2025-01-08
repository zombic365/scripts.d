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

##### Common functio
TODAY=$(date +%y%m%d_%H%M%S)
function log_msg() {
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

function run_cmd() {
    _CMD=$@
    printf "CMD: [ ${_CMD} ]\n" >>./script_cmd_${TODAY}.log 2>&1
    log_msg "CMD" "$@"
    
    eval "${_CMD}" >>./script_cmd_${TODAY}.log 2>&1
    if [ $? -eq 0 ]; then
        log_msg "OK"
        return 0
    else
        log_msg "FAIL"
        return 1
    fi
}


if [ ! -d /APP/gitlab.d ]; then
    run_cmd "mkdir -p /APP/gitlab.d/{etc.log}"
fi
if [ ! -d /DATA/gitlab.d ]; then
    run_cmd "mkdir -p /DATA/gitlab.d"
    run_cmd "ln -s /DATA/gitlab.d /APP/gitlab.d/data"
fi

run_cmd "cat <<EOF >/APP/gitlab.d/docker-compose.yml
version: '3.9'
services:
    gitlab:
        image: 'gitlab/gitlab-ce'
        container_name: gitlab
        restart: always
        enviroment:
            GITLAB_OMNIBUS_CONFIG: |
                external_url 'https://citgit.enter-citech.toastmaker.net'
                gitlab_rails['gitlab_shell_ssh_port'] = 8022
            TZ: 'Asia/Seoul'
        ports:
        - '80:80'
        - '443:443'
        - '8022:20165'
        volumes:
        - './config:/APP/gitlab.d/etc'
        - './logs:/APP/gitlab.d/log'
        - './data:/DATA/gitlab.d'
EOF"