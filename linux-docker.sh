#!/bin/bash

# Reset
ResetCl='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BOLD='\033[0;1m'          # Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

function run_command() {
    command=$@
    logging_message "CMD" "$@"    
    eval "${command}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        logging_message "OK"
        return 0
    else
        logging_message "FAIL"
        return 1
    fi
}

function logging_message() {
    # cmd_log="tee -a ${SCRIPT_LOG}/script_${TODAY}.log"
    run_today=$(date "+%y%m%d")
    run_time=$(date "+%H:%M:%S.%3N")
  
    log_time="${run_today} ${run_time}"
    log_type=$1
    log_msg=$2

    # printf "%-*s | %s\n" ${STR_LEGNTH} "Server Serial" "Unknown" |tee -a ${LOG_FILE} >/dev/null
    case ${log_type} in
        "CMD"   ) printf "%s | ${BOLD}%-*s${ResetCl} | ${BOLD}%s${ResetCl}\n"  "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "OK"    ) printf "%s | ${Green}%-*s${ResetCl} | ${Green}%s${ResetCl}\n"  "${log_time}" 7 "${log_type}" "command ok."   ;;
        "FAIL"  ) printf "%s | ${Red}%-*s${ResetCl} | ${Red}%s${ResetCl}\n"      "${log_time}" 7 "${log_type}" "command fail." ;;
        "INFO"  ) printf "%s | ${Cyan}%-*s${ResetCl} | %s${ResetCl}\n"           "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "WARR"  ) printf "%s | ${Red}%-*s${ResetCl} | %s${ResetCl}\n"            "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "SKIP"  ) printf "%s | ${Yellow}%-*s${ResetCl} | %s${ResetCl}\n"         "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "ERROR" ) printf "%s | ${BRed}%-*s${ResetCl} | %s${ResetCl}\n"           "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
    esac
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
            -i | --install )
                pre_install_docker
                if [ $? -eq 0 ]; then
                    install_docker
                    exit 0
                else
                    logging_message "CRT" "Install docker check fail"
                    exit 1
                fi
            ;;
            -r | --remove ) remove_docker ; exit 0 ;;
            -h | --help ) help_usage ;;
            -- ) shift ; break ;;
            *  ) help_usage ;;
        esac
    done
    
    ### 남아 있는 인자를 얻기 위해 shift 한다.
    shift $((OPTIND-1))
}

function pre_cmd_check() {
    _check_cmd=("curl" "dnf-plugins-core")
    _check_cmd_fail=()

    for((i=0; i<=${#_check_cmd[@]}; i++)); do
        run_command "dnf list installed |grep -q ^${_pkg}"
        if [ $? -eq 1 ]; then
            _check_cmd_fail+=${_pkg}
        fi
    done

    if [ -n ${_check_cmd_fail} ]; then
        logging_message "ERROR" "Please check Command, Packages [ ${_check_cmd_fail[@]} ]"
        return 1
    else
        return 0
    fi
}

function pre_pkg_check() {
    # _check_pkg=(curl)
    _check_pkg=$2
    _check_pkg_fail=()

    if dnf list installed |grep -q "^${_pkg}"; then
        return 0
    else
        return 1
    done
    # for((i=0; i<=${#_check_pkg[@]}; i++)); do
    #     run_command "dnf list installed |grep -q ^${_pkg}"
    #     if [ $? -eq 1 ]; then
    #         _check_pkg_fail+=${_pkg}
    #     fi
    # done

    # if [ -n ${_check_pkg_fail} ]; then
    #     logging_message "CRT" "Please check Command, Packages [ ${_check_pkg_fail[@]} ]"
    #     return 1
    # else
    #     return 0
    # fi
}

function pre_install_docker() {
    ##### Docker repository add for rocky
    # if [ -f /etc/yum.repos.]
    run_command "dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
    if [ $? -eq 0 ]; then
        run_command "dnf repolist"
        if [ $? -eq 0 ]; then
            return 0
        fi
    fi
}

function install_docker() {
    for _pkg in "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"; do
        pre_pkg_check "${_pkg}"
        if [ $? -eq 1 ];
            run_command "dnf install -y ${_pkg}"
        fi
    done

    run_command "sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose"
    if [ $? -eq 0 ]; then
        if ! grep -q '/usr/local/bin' ${HOME}/.bash_profile; then
            run_command "sed -i '/export PATH/i\PATH=\$PATH:/usr/local/bin' ${HOME}/.bash_profile"
        fi
        run_command "chmod +x /usr/local/bin/docker-compose"
        [ $? -eq 0 ] && return 0 || return 1
    else
        logging_message "ERROR" "Download fail docker-compose."
        return 1
    fi
}

function remove_docker() {
    for _pkg in "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin" "docker-ce-rootless-extras"; do
        run_command "dnf remove -y ${_pkg}"
    done

    run_command "rm -f /etc/yum.repos.d/docker-ce.repo"
    run_command "rm -rf /var/lib/docker"
    run_command "rm -rf /var/lib/containerd"
}

main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"

    case ${MODE} in
        "install" )
            pre_install_docker
            if [ $? -eq 0 ]; then
                install_docker
                if [ $? -eq 0 ]; then
                    logging_message "INFO" "Complete install docker & docker-compose and excute command [ source ${HOME}/.bash_profile ]."
                    exit 0
                else
                    exit 1
                fi
            else
                exit 1
            fi
        ;;
        "remove"  ) ;;
    esac
}
main $*