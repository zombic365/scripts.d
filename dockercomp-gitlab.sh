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
function logging_message() {
    cmd_log="tee -a ./$(basename "$0")_script_${TODAY}.log"
    run_today=$(date "+%y%m%d")
    run_time=$(date "+%H:%M:%S.%3N")
  
    log_time="${BWhite}[ ${run_today} ${run_time} ]${Color_Off}"
    log_type=$1
    log_msg=$2

    case ${log_type} in
        "CMD")   printf "${log_time} ${BWhite}[${log_type}] ${log_msg}${Color_Off}: "         |eval "${cmd_log}" ;;
        "OK")    printf "${BGreen}${log_type}${Color_Off}\n"                                  |eval "${cmd_log}" ;;        
        "FAIL")  printf "${BRed}${log_type}${Color_Off}\n"                                    |eval "${cmd_log}" ;;
        "SKIP")  printf "${BPurple}${log_type} ${BWhite}-> ${log_msg}${Color_Off}\n"          |eval "${cmd_log}" ;;
        "WARR")  printf "${log_time} ${BCyan}[${log_type}] ${log_msg}${Color_Off}\n"          |eval "${cmd_log}" ;;
        "INFO")  printf "${log_time} ${BWhite}[${log_type}] ${log_msg}${Color_Off}\n"         |eval "${cmd_log}" ;;
        "CRT")   printf "${log_time} ${BWhite}[${log_type}] ${BRed}${log_msg}${Color_Off}\n"  |eval "${cmd_log}" ;;
    esac
}

function run_command() {
    command=$@
    printf "CMD: [ ${command} ]\n" >>./$(basename "$0")_script_command_${TODAY}.log 2>&1
    logging_message "CMD" "$@"
    
    eval "${command}" >>./$(basename "$0")_script_command_${TODAY}.log 2>&1
    if [ $? -eq 0 ]; then
        logging_message "OK"
        return 0
    else
        logging_message "FAIL"
        return 1
    fi
}

function help_msg() {
    cat <<EOF
Usage: $0 [Options]
Options:
-u, --url : Server IP or Your Domain url
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options u:ph \
    --longoptions url:password,help \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"

    while true; do
        case "$1" in
            -u | --url       ) GITLAB_DOMAIN=$2        ; shift 2 ;;
            -p | --password  )
                GITLAB_ROOT_PASSWORD=$2
                if [ -z ${GITLAB_ROOT_PASSWORD} ]; then
                    GITLAB_ROOT_PASSWORD="gitrootpass!@#123"
                fi
                shift 2 ;;
            -h | --help ) help_msg      ;;
                     -- ) shift ; break ;;
                      * ) help_msg      ;;
        esac
    done

    shift $((OPTIND-1))

    [ -z ${GITLAB_DOMAIN} ] && help_msg
}

function create_file() {
    run_command "cat <<EOF >/APP/gitlab.d/docker-compose.yml
services:
    gitlab:
        image: 'gitlab/gitlab-ce'
        container_name: gitlab
        restart: always
        environment:
            GITLAB_OMNIBUS_CONFIG: |
                external_url 'http://${GITLAB_DOMAIN}'
                gitlab_rails['gitlab_shell_ssh_port'] = 22
            TZ: 'Asia/Seoul'
            GITLAB_ROOT_PASSWORD: ${GITLAB_ROOT_PASSWORD}
            sidekiq['concurrency'] = 10
            prometheus_monitoring['enable'] = false
        ports:
        - '8080:80'
        - '8443:443'
        - '8022:22'
        volumes:
        - '/APP/gitlab.d/etc:/etc/gitlab'
        - '/APP/gitlab.d/log:/var/log/gitlab'
        - '/DATA/gitlab.d/:/var/opt/gitlab'
EOF"
}

function main() {
    [ $# -eq 0 ] && help_msg
    set_opts "$@"

    if [ ! -d /APP/gitlab.d ]; then
        run_command "mkdir -p /APP/gitlab.d/{etc,log}"
    else
        logging_message "SKIP" "Already directory"
    fi

    if [ ! -d /DATA/gitlab.d ]; then
        run_command "mkdir -p /DATA/gitlab.d"
        run_command "ln -s /DATA/gitlab.d /APP/gitlab.d/data"
    else
        logging_message "SKIP" "Already directory"
    fi

    if [ -f /APP/gitlab.d/docker-compose.yml ]; then
        logging_message "WARR" "Already file"
        read -p 'Re-create file? (Y|n) ' answer
        case ${answer} in
            y | Y ) cp -p /APP/gitlab.d/docker-compose.yml /APP/gitlab.d/docker-compose.yml_$(date +%Y%m%d_%H%M%S) ; create_file ;;
            n | N ) logging_message "SKIP" "Already file" ;;
            * )     cp -p /APP/gitlab.d/docker-compose.yml /APP/gitlab.d/docker-compose.yml_$(date +%Y%m%d_%H%M%S) ; create_file ;;
        esac
    else
        create_file
    fi

    echo ""
    echo -e "${BWhite}Script done. please excute '${BGreen}docker-compose -f /APP/gitlab.d/docker-compose.yml up -d${BWhite}'${Color_Off}"
    echo -e "${BWhite}below your gitlab default id, password${Color_Off}"
    echo -e "${BWhite}id: root${Color_Off}"
    echo -e "${BWhite}pw: ${GITLAB_ROOT_PASSWORD}${Color_Off}"
}
main $*