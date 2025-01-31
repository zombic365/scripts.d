#/bin/bash

### 프롬포트 색상
ResetCl='\033[0m'       # Text Reset

Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

BOLD='\033[0;1m'          # Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

UWhite='\033[4;37m'       # White

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

function install_kafka() {
    [ ! -d ${KAFKA_PATH} ] && run_command "mkdir -p ${KAFKA_PATH}"

    ### Kafka 파일 다운 및 기본 구성
    if [ ! -f ${KAFKA_PATH}/kafka_2.13-3.9.0.tgz ]; then
        run_command "wget https://dlcdn.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz -P ${KAFKA_PATH}"
        run_command "tar -zxf ${KAFKA_PATH}/kafka_2.13-3.9.0.tgz -C ${KAFKA_PATH}"
    fi

    if [ ! -d ${KAFKA_PATH}/kafka.d ]; then
        run_command "cd ${KAFKA_PATH}; ln -s ./kafka_2.13-3.9.0 kafka.d"
    fi

    ### kafka.d/bin 파일 환경변수로 등록
    if ! grep -q 'kafka.d' ${HOME}/.bash_profile; then
        run_command "sed -i '/export PATH/i\PATH=\$PATH:${KAFKA_PATH}\/kafka.d\/bin' ${HOME}/.bash_profile"
    fi

    ### kafka cluster에서 사용할 고유 UUID 생성
    if [ ! -f ${KAFKA_PATH}/kafka.d/kafka-cluster-uuid.tmp ]; then
        run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh random-uuid >${KAFKA_PATH}/kafka.dkafka-cluster-uuid.tmp"
    fi

    local KAFKA_CLUSTER_ID="$(cat ${KAFKA_PATH}/kafka.d/kafka-cluster-uuid.tmp)"

    ### kraft 로그 경로 변경
    run_command "cp -p ${KAFKA_PATH}/config/kraft/reconfig-server.properties ${KAFKA_PATH}/config/kraft/reconfig-server.properties_$(date +%y%m%d_%H%M%S)"

    if ! grep -q '${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs' ${KAFKA_PATH}/config/kraft/reconfig-server.properties; then
        run_command "sed -i 's/^log.dirs/#&/g' ${KAFKA_PATH}/config/kraft/reconfig-server.properties"
        run_command "sed -i '/^#log.dirs/a\log.dirs=\${KAFKA_PATH}\/kafka.d\/logs\/kraft-combined-logs' ${KAFKA_PATH}/config/kraft/reconfig-server.properties"
    fi

    ### kafka 데이터 포맷
    if [ ! -d ${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs ]; then    
        run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format --standalone -t ${KAFKA_CLUSTER_ID} -c ${KAFKA_PATH}/config/kraft/reconfig-server.properties"
    fi

    ### systemd 파일 생성
    if [ ! -f /usr/lib/systemd/system/kafka.service ]; then
        run_command "cat <<EOF >/usr/lib/systemd/system/kafka.service
[Unit]
Description=kafka
After=syslog.target
After=network.target

[Service]
Type=simple
Restart=on-failure
ExecStart=/bin/sh -c '${KAFKA_PATH}/bin/kafka-server-start.sh ${KAFKA_PATH}/config/kraft/reconfig-server.properties'
ExecStop=/bin/sh -c '${KAFKA_PATH}/bin/kafka-server-stop.sh'

[Install]
WantedBy=multi-user.target
EOF"
    fi
}

function help_usage() {
    echo -e "
${UWhite}Usage${ResetCl}: $0 [-i | -r] --app-dir ${IWhite}<KAFKA_PATH>${ResetCl}
                        [--running] [--verbose]

${UWhite}Positional arguments${ResetCl}:
--kafka-dir ${IWhite}<KAFKA_PATH>${ResetCl}
                  Kafka download, application path
                  ex) --kafka-dir /APP -> KAFKA_PATH="/APP/kafka.d"

${UWhite}Options${ResetCl}:
-h, --help        Show this hel message and exit
-i                Install binaray kafka
-r                Remove binaray kafka

--running
                  When the ELK setup is complete, The service will running.
--verbose
                  Prints in more detail about the script.
"
    exit 0
}

function set_opts() {
    arguments=$(getopt --options irh \
    --longoptions help,kafka-dir:,running,verbose \
    --name $(basename $0) \
    -- "$@")

    KAFKA_ACTIVE=1
    DEBUG_MODE="no"
    eval set -- "${arguments}"
    while true; do
        case "$1" in
            -h | --help ) help_usage    ;;
            -i ) MODE="install" ; shift ;;
            -r ) MODE="remove"  ; shift ;;
            --kafka-dir ) export KAFKA_PATH="$2"  ; shift 2 ;;
            --running   ) export KAFKA_ACTIVE=0   ; shift   ;;
            --verbose   ) export DEBUG_MODE="yes" ; shift   ;;
            -- ) shift ; break ;;
            *  ) help_usage ;;
        esac
    done

    if [ ! -n ${KAFKA_PATH} ]; then
        printf "${Red}--kafka-dir option NULL.${ResetCl}\n"
        help_usage
    fi
    shift $((OPTIND-1))
}

main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"

    if javac --version |grep -Eq '8|11|17'; then
        logging "ERROR" "Supported Java version 8,11,17, please check java."
        exit 1 
    fi

    case ${MODE} in
        "install" )
            install_kafka
            if [ $? -eq 0 ]; then
                if [ ${KAFKA_ACTIVE} -eq 0 ]; then
                    if [ ! -f /usr/lib/systemd/system/kafka.service ]; then
                        run_command "systemctl daemon-reload"                
                    fi
                    
                    run_command "systemctl start kafka"
                    if [ $? -eq 0 ]; then
                        logging "INFO" "Install completed."
                        exit 0
                    else
                        exit 1
                    fi
                else
                    logging "INFO" "The installation is complete, please perform the command below."
                    logging "INFO" "systemctl start kafka"
                    exit 0
                fi
            else
                exit 1
            fi
        ;;
        "remove" )
            remove_kafka
        ;;
    esac
}
main $*