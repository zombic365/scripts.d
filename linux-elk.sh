#!/bin/bash

# 참조 blog
# https://velog.io/@mnetna/X-PACK-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%AC%B4%EB%A3%8C-%EA%B8%B0%EB%8A%A5-%EC%82%AC%EC%9A%A9
# https://blog.binarynum.com/62
# https://jjeong.tistory.com/1433
# https://github.com/elastic/elasticsearch/blob/main/distribution/packages/src/common/systemd/elasticsearch.service
# https://velog.io/@91savage/ELK-Stack-Elasticsearch-Logstash-Kibana-debian-%EC%84%A4%EC%B9%98
# https://ploz.tistory.com/entry/logstash-elasticsearch-cluster%EC%97%90-logstash-%EB%B6%99%EC%97%AC%EB%B3%B4%EA%B8%B0SSL-%ED%8F%AC%ED%95%A8

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
-i, --install             : Install ELK
-r, --remove              : Remove  ELK
-u, --user [ STRING ]     : ELK User
-s, --svr  [ STRING ]     : ELK Service name
-p, --path [ STRING ]     : ELK Path
-v, --ver  [  INT   ]     : ELK Version
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options u:s:p:v:hir \
    --longoptions user:,svr:,path:,ver:,help,install,remove \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"
    while true; do
        case "$1" in
            -i | --install  ) MODE="install"; shift   ;;
            -r | --remove   ) MODE="remove" ; shift   ;;
            -u | --user     ) ELK_USER=$2   ; shift 2 ;;
            -s | --svr      ) ELK_SVR=$2    ; shift 2 ;;
            -p | --path     ) ELK_PATH=$2   ; shift 2 ;;
            -v | --ver      ) ELK_VER=$2    ; shift 2 ;;
            -h | --help     ) help_message              ;;            
            --              ) shift         ; break   ;;
            ?               ) help_message              ;;
        esac
    done
    ### 남아 있는 인자를 얻기 위해 shift 한다.
    shift $((OPTIND-1))
}

function setup_config() {
    if [ ! -d ${ELK_PATH}/tools/pkgs ]; then
        run_command "mkdir -p ${ELK_PATH}/tools/pkgs"
    fi
}

function download_pkgs() {
    for svc_name in elasticsearch logstash kibana; do
        run_command "curl -s https://artifacts.elastic.co/downloads/${svc_name}/${svc_name}-${ELK_VER}-linux-x86_64.tar.gz >${ELK_PATH}/tools/pkgs/${svc_name}-${ELK_VER}-linux-x86_64.tar.gz"
        run_command "curl -s https://artifacts.elastic.co/downloads/${svc_name}/${svc_name}-${ELK_VER}-linux-x86_64.tar.gz.sha512 >${ELK_PATH}/tools/pkgs/${svc_name}-${ELK_VER}-linux-x86_64.tar.gz.sha512"
        run_command "cd ${ELK_PATH}/tools/pkgs"
        run_command "shasum -a 512 -qc ${svc_name}-${ELK_VER}-linux-x86_64.tar.gz.sha512"
        if [ $? -eq 0 ]; then
            if [ ! -d ${ELK_PATH}/${svc_name}-${ELK_VER}-linux-x86_64 ]; then
                run_command "tar -zxf ${svc_name}-${ELK_VER}-linux-x86_64.tar.gz -C ${ELK_PATH}/."
                run_command "cd ${ELK_PATH}"
            else
                logging_message "SKIP" "Already install ${ELK_PATH}/${svc_name}-${ELK_VER}-linux-x86_64"
                continue
            fi

            if [ ! -f ${ELK_PATH}/${svc_name} ]; then
                run_command "ln -s ${ELK_PATH}/${svc_name} ${svc_name}"
            else
                logging_message "WARR" "Already ${ELK_PATH}/${svc_name}, so Change new [ ${svc_name}-${ELK_VER}-linux-x86_64 ]"
                run_command "ln -Tfs ${ELK_PATH}/${svc_name} ${svc_name}"
            fi

            logging_message "INFO" "Sucess Install ${svc_name}"
        else
            logging_message "ERROR" "Download error ${svc_name}-${ELK_VER}"
            exit 1
        fi
    done
}

main() {
    [ $# -eq 0 ] && help_message
    set_opts "$@"

    if [ ! -d ${ELK_PATH} ]; then
        logging_message "ERROR" "Pleaase check path ${ELK_PATH}"
        exit 1
    else    
        setup_config
        case ${MODE} in
            "install" )
                download_pkgs
            ;;
            "remove"  ) echo "remote"  ; exit 0 ;;
            *         ) help_message     ; exit 0 ;;
        esac
    fi
}
main $*