#!/bin/bash

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
    cmd_log="tee -a ${SCRIPT_LOG}/script_${TODAY}.log"
    run_today=$(date "+%y%m%d")
    run_time=$(date "+%H:%M:%S.%3N")
  
    log_time="${run_today} ${run_time}"
    log_type=$1
    log_msg=$2

    # printf "%-*s | %s\n" ${STR_LEGNTH} "Server Serial" "Unknown" |tee -a ${LOG_FILE} >/dev/null
    case ${log_type} in
        "CMD"   ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "OK"    ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "command ok."   ;;
        "FAIL"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "command fail." ;;
        "INFO"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "WARR"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "SKIP"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        "ERROR" ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   ;;
        # "CMD"   ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   |tee -a ${LOG_FILE} >/dev/null ;;
        # "OK"    ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "command ok."   |tee -a ${LOG_FILE} >/dev/null ;;
        # "FAIL"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "command fail." |tee -a ${LOG_FILE} >/dev/null ;;
        # "INFO"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   |tee -a ${LOG_FILE} >/dev/null ;;
        # "WARR"  ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   |tee -a ${LOG_FILE} >/dev/null ;;
        # "ERROR" ) printf "%s | %-*s | %s\n" "${log_time}" 7 "${log_type}" "${log_msg}"   |tee -a ${LOG_FILE} >/dev/null ;;
    esac
}

function help_message() {
    cat <<EOF
Usage: $0 [Options]
Options:
-i, --install          : Install Rundeck
-r, --remove           : Remove  Rundeck
-p, --path [ STRING ]  : Rundeck config path
-h, --help             : Script Help
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options p:irh \
    --longoptions path:,help,install,remove \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"
    while true; do
        case "$1" in
            -i | --install  ) MODE="install"; shift   ;;
            -r | --remove   ) MODE="remove" ; shift   ;;
            -p | --path     ) RDECK_BASE=$2   ; shift 2 ;;
            -h | --help     ) help_message              ;;            
            --              ) shift         ; break   ;;
            ?               ) help_message              ;;
        esac
    done

    shift $((OPTIND-1))
    [ -z ${RDECK_BASE} ] && help_msg
}

function install_rundeck() {
    if [ ! -d ${RDECK_BASE} ]; then
        mkdir -p ${RDECK_BASE}
    else
        logging_message "SKIP" "Already ${RDECK_BASE}"
    fi

    run_command "wget https://packagecloud.io/pagerduty/rundeck/packages/java/org.rundeck/rundeck-5.8.0-20241205.war/artifacts/rundeck-5.8.0-20241205.war/download?distro_version_id=167 \
    -O ${RDECK_BASE}/rundeck-5.8.0-20241205.war"
    run_command "java -Xmx4g -jar ${RDECK_BASE}/rundeck-5.8.0-20241205.war"
}
    

function main() {
    [ $# -eq 0 ] && help_message
    set_opts "$@"
}
main $*
export PATH=$PATH:$RDECK_BASE/tools/bin
export MANPATH=$MANPATH:$RDECK_BASE/docs/man

### war파일 실행, 종료
java -Xmx4g -jar rundeck-5.8.0-20241205.war
# ctrl + c

### rundeck-config.properties파일 수정후 재기동
cp -p $RDECK_BASE/server/config/rundeck-config.properties $RDECK_BASE/server/config/rundeck-config.properties.bk_$(date +%y%m%d_%H%M%S)
sed -i 's/server.address/#&/g' $RDECK_BASE/server/config/rundeck-config.properties
sed -i '/^#server.address/a\server.address=0.0.0.0' $RDECK_BASE/server/config/rundeck-config.properties

sed -i 's/grails.serverURL/#&/g' $RDECK_BASE/server/config/rundeck-config.properties
sed -i '/^#grails.serverURL/a\grails.serverURL=http://211.233.50.183:4440' $RDECK_BASE/server/config/rundeck-config.properties

### 업데이트 후 다시 수행
java -Xmx4g -jar rundeck-5.8.0-20241205.war




### Ansible 설정
mkdir -p /DATA/ansible.d/os_hardenning