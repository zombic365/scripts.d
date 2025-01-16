#!/bin/bash
### 참고 자료
# docker compose elk: https://github.com/deviantony/docker-elk
# 블로그 자료: https://velog.io/@jimjimi/Elasticsearch-%EB%AC%B4%EC%9E%91%EC%A0%95-%EB%82%98%EB%A7%8C%EC%9D%98-%EA%B2%80%EC%83%89%EC%97%94%EC%A7%84-%EA%B5%AC%EC%B6%95%ED%95%98%EA%B8%B0-Windows-Docker-ELK-%EC%8A%A4%ED%83%9DElasticsearch-Logstash-Kibana-%ED%99%9C%EC%9A%A9

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

# Underline
UWhite='\033[4;37m'       # White

# Italic
ITALIC='\033[0;3m'          # Bold
IBlack='\033[3;30m'       # Black
IRed='\033[3;31m'         # Red
IGreen='\033[3;32m'       # Green
IYellow='\033[3;33m'      # Yellow
IBlue='\033[3;34m'        # Blue
IPurple='\033[3;35m'      # Purple
ICyan='\033[3;36m'        # Cyan
IWhite='\033[3;37m'       # White

function run_command() {
    local COMMAND=$@

    case ${DEBUG_MODE} in
        "yes" )
            logging "CMD" "${COMMAND}"
            eval "${COMMAND}" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                logging "OK"
                return 0
            else
                logging "FAIL"
                return 1
            fi
        ;;

        "no"  )
            eval "${COMMAND}" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                return 0
            else
                return 1
            fi
        ;;
    esac
}

function logging() {
    local log_time=$(date "+%y%m%d %H:%M:%S.%3N")
    local log_type="$1"
    local log_msg="$2"
    
    # cmd_log="tee -a ${SCRIPT_LOG}/script_${TODAY}.log"
    # printf "%-*s | %s\n" ${STR_LEGNTH} "Server Serial" "Unknown" |tee -a ${LOG_FILE} >/dev/null
    case ${log_type} in
        "CMD"   ) printf "%s | ${BOLD}%-*s${ResetCl} | ${BOLD}%s${ResetCl}\n"    "${log_time}" 7 "${log_type}" "${log_msg}"    ;;
        "OK"    ) printf "%s | ${Green}%-*s${ResetCl} | ${Green}%s${ResetCl}\n"  "${log_time}" 7 "${log_type}" "command ok."   ;;
        "FAIL"  ) printf "%s | ${Red}%-*s${ResetCl} | ${Red}%s${ResetCl}\n"      "${log_time}" 7 "${log_type}" "command fail." ;;
        "INFO"  ) printf "%s | ${Cyan}%-*s${ResetCl} | %s${ResetCl}\n"           "${log_time}" 7 "${log_type}" "${log_msg}"    ;;
        "WARR"  ) printf "%s | ${Red}%-*s${ResetCl} | %s${ResetCl}\n"            "${log_time}" 7 "${log_type}" "${log_msg}"    ;;
        "SKIP"  ) printf "%s | ${Yellow}%-*s${ResetCl} | %s${ResetCl}\n"         "${log_time}" 7 "${log_type}" "${log_msg}"    ;;
        "ERROR" ) printf "%s | ${BRed}%-*s${ResetCl} | %s${ResetCl}\n"           "${log_time}" 7 "${log_type}" "${log_msg}"    ;;
    esac
}

function help_usage() {
    echo -e "
${UWhite}Usage${ResetCl}: $0 [-i | -r] <ELK_NAME> --data-dir ${IWhite}<ELK_PATH>${ResetCl}
                        [--elk-ver  ${IWhite}<ELK_VERSION>${ResetCl}]
                        [--running] [--verbose]

${UWhite}Positional arguments${ResetCl}:
${IWhite}<ELK_NAME>${ResetCl}
                  ELK service name
--data-dir ${IWhite}<ELK_DATA_PATH>${ResetCl}
                  ELK application path

${UWhite}Options${ResetCl}:
-h, --help        Show this hel message and exit
-i                Install docker-compose based elk
-r                Remove docker-compose based elk

--elk-ver  ${IWhite}<ELK_VERSION>${ResetCl}
                  ELK application version (default. 8.17.0)
--running
                  When the ELK setup is complete, The service will running.
--verbose
                  Prints in more detail about the script.
"
    exit 0
}

function set_opts() {
    arguments=$(getopt --options irh \
    --longoptions help,data-dir:,elk-ver:,running,verbose \
    --name $(basename $0) \
    -- "$@")

    ELK_ACTIVE=1
    DEBUG_MODE="no"
    eval set -- "${arguments}"
    while true; do
        case "$1" in
            -h | --help ) help_usage    ;;
            -i ) MODE="install" ; shift ;;
            -r ) MODE="remove"  ; shift ;;
            --data-dir ) ELK_PATH="$2"    ; shift 2 ;;
            --elk-ver  ) ELK_VERSION="$2" ; shift 2 ;;
            --running  ) ELK_ACTIVE=0     ; shift   ;;
            --verbose  ) DEBUG_MODE="yes" ; shift   ;;
            -- ) shift ; break ;;
            *  ) help_usage ;;
        esac
    done

    [ ! -n ${ELK_VERSION} ] && ELK_VERSION="8.17.0"
    if [ ! -n ${ELK_PATH} ]; then
        printf "${Red}--data-dir option NULL.${ResetCl}\n"
        help_usage
    fi
    shift $((OPTIND-1))
}

function gen_pass() {
    local ARR_PASS_NAME=( "ELASTIC" "LOGSTASH_INTERNAL" "KIBANA_SYSTEM" "METRICBEAT_INTERNAL" "FILEBEAT_INTERNAL" "HEARTBEAT_INTERNAL" "MONITORING_INTERNAL" "BEATS_SYSTEM" )

    for pass_name in ${ARR_PASS_NAME[@]}; do
        pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')
        run_command "sed -i \"s/^${pass_name}_PASSWORD/#&/g\" ${ELK_PATH}/.env"
        run_command "sed -i \"/^#${pass_name}_PASSWORD/a\\${pass_name}_PASSWORD=\"${pass}\"\" ${ELK_PATH}/.env"
    done
}

function pre_elk() {
    if [ ! -d ${ELK_PATH} ]; then
        run_command "mkdir -p ${ELK_PATH}"
    else
        logging "SKIP" "${ELK_PATH} dir already exists."
    fi

    if [ ! -f ${ELK_PATH}/docker-compose.yml ]; then
        run_command "git clone https://github.com/deviantony/docker-elk ${ELK_PATH}"
        if [ $? -eq 0 ]; then
            gen_pass
        else
            logging "ERROR" "Dir download fail."
            return 1
        fi

        local LINE_NUM=$(grep -n 'depends_on' ${ELK_PATH}/docker-compose.yml |awk -F':' '{print $1}' |head -n1)
        local APPEND_LINE_NUM=$(expr ${LINE_NUM} + 2)
        run_command "sed -i '${APPEND_LINE_NUM}i\      - logstash\n      - kibana' ${ELK_PATH}/docker-compose.yml"
        if [ $? -eq 0 ]; then
            return 0
        else
            return 1
        fi
    else
        logging "SKIP" "${ELK_PATH}/docker-compose.yml file already exists. please file check."
        return 1
    fi
}

function istanll_elk() {
    run_command "docker-compose up -f ${ELK_PATH}/docker-compose.yml setup"
    if [ $? -eq 0 ]; then
        run_command "docker-compose -f ${ELK_PATH}/docker-compose.yml up -d"
        return 0
    else
        logging "ERROR" "docker-compose up setup fail."
        return 1
    fi
}

function remove_elk() {
    if ! docker ps -a --format "table {{.ID}}\t{{.Names}}" |grep -q $(basename "${ELK_PATH}" |tr -d '[:punct:]'); then
        logging "SKIP" "Container not running"
    else
        while read -r container_id container_name; do
            logging "INFO" "Delete ${container_name} [ ${container_id} ]"
        done <<<$(docker ps -a --format "table {{.ID}}\t{{.Names}}" |grep $(basename "${ELK_PATH}" |tr -d '[:punct:]'))

        read -p "Contiue? (Y|n)" _ans
        case ${_ans} in
            [yY] )
                run_command "docker-compose -f ${ELK_PATH}/docker-compose.yml down"
                while read -r container_id container_name; do
                    run_command "docker rm ${container_id}"
                done <<<$(docker ps -a --format "table {{.ID}}\t{{.Names}}" |grep $(basename "${ELK_PATH}" |tr -d '[:punct:]'))
            ;;
            [nN] ) return 1 ;;
            *    )
                run_command "docker-compose -f ${ELK_PATH}/docker-compose.yml down"
                while read -r container_id container_name; do
                    run_command "docker rm ${container_id}"
                done <<<$(docker ps -a --format "table {{.ID}}\t{{.Names}}" |grep $(basename "${ELK_PATH}" |tr -d '[:punct:]'))
            ;;
        esac
    fi

    if  [ -d ${ELK_PATH} ]; then
        run_command "rm -rf ${ELK_PATH}"
    else
        logging "SKIP" "${ELK_PATH} dir not exists."
    fi
}

main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"

    case ${MODE} in
        "install" )
            pre_elk
            if [ $? -eq 0 ]; then
                if [ ${ELK_ACTIVE} -eq 0 ]; then
                    install_elk
                    if [ $? -eq 0 ]; then
                        logging "INFO" "Install completed."
                        exit 0
                    else
                        exit 1
                    fi
                else
                    logging "INFO" "The installation is complete, please perform the command below."
                    logging "INFO" "docker-compose -f ${ELK_PATH}/docker-compose.yml up setup && docker-compose -f ${ELK_PATH}/docker-compose.yml up -d"
                    exit 0
                fi
            else
                exit 1
            fi
        ;;
        "remove" )
            remove_elk
        ;;
    esac
}
main $*