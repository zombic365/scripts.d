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

##################
### Kafak 바이너리 파일을 다운 및 링크 설정
##################
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
}

##################
### Kafak+Zookeeper 환경 설정
##################
function setup_zookeeper_cluster() {
    ### Zookeeper를 사용하기 위한 kafka 설정
    KAFKA_CONFIG_PATH="${KAFKA_PATH}/kafka.d/config/server.properties"
    KAFKA_ZOOKEEPER_PATH="${KAFKA_PATH}/kafka.d/config/zookeeper.properties"

    if ! grep -q "zookeeper.connect=.*.${EXTERNAL_IP}:2181.*." ${KAFKA_CONFIG_PATH}; then
        run_command "cp -p ${KAFKA_CONFIG_PATH} ${KAFKA_CONFIG_PATH}_$(date +%y%m%d_%H%M%S)"

        ### --cluster-ips에 기재된 IP입력 순서를 기준으로 broker id 할당
        local _tmp_line=()
        local _num=0
        for (( idx=0;idx<${#CLUSTER_IPS[@]};idx++ )); do
            _num=$(expr $idx + 1)
            _tmp_line+=("${CLUSTER_IPS[${idx}]}:2181")
            if [ "${CLUSTER_IPS[${idx}]}" == "${EXTERNAL_IP}" ]; then
                ### Broker id 수정
                if ! grep "^broker.id=${_num}" ${KAFKA_CONFIG_PATH}; then
                    run_command "sed -i 's/^broker.id/#&/g' ${KAFKA_CONFIG_PATH}"
                    run_command "sed -i \"/^#broker.id/a\broker.id=${_num}\" ${KAFKA_CONFIG_PATH}"
                fi
            fi
        done

        ### listeners 수정
        if ! grep -q "^listeners=PLAINTEXT://${EXTERNAL_IP}:9092" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^listeners=PLAINTEXT/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i \"/^#listeners=PLAINTEXT/a\listeners=PLAINTEXT://${EXTERNAL_IP}:9092\" ${KAFKA_CONFIG_PATH}"
        fi

        ### advertised.listeners 수정
        if ! grep -q "^advertised.listeners=PLAINTEXT://${EXTERNAL_IP}:9092" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^advertised\.listeners=PLAINTEXT/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i \"/^#advertised\.listeners=PLAINTEXT/a\advertised.listeners=PLAINTEXT://${EXTERNAL_IP}:9092\" ${KAFKA_CONFIG_PATH}"
        fi

        ### log.dirs 수정
        if ! grep -q '${KAFKA_PATH}/kafka.d/logs' ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^log.dirs/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#log.dirs/a\log.dirs=${KAFKA_PATH}\/kafka.d\/logs' ${KAFKA_CONFIG_PATH}"
        fi

        ### num.partitions 수정
        if ! grep -q "num.partitions=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^num.partitions/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#num.partitions/a\num.partitions=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi
    
        ### offsets.topic.replication.factor 수정
        if ! grep -q "offsets.topic.replication.factor=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^offsets.topic.replication.factor/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#offsets.topic.replication.factor/a\offsets.topic.replication.factor=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi

        ### transaction.state.log.replication.factor 수정
        if ! grep -q "transaction.state.log.replication.factor=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^transaction.state.log.replication.factor/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#transaction.state.log.replication.factor/a\transaction.state.log.replication.factor=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi

        ### transaction.state.log.min.isr 수정
        if ! grep -q "transaction.state.log.min.isr=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^transaction.state.log.min.isr/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#transaction.state.log.min.isr/a\transaction.state.log.min.isr=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi

        ### zookeeper.connect 수정
        run_command "sed -i 's/^zookeeper.connect=/#&/g' ${KAFKA_CONFIG_PATH}"
        run_command "sed -i \"/^#zookeeper.connect=/a\zookeeper.connect=$(echo "${_tmp_line[@]}" |sed 's/ /,/g')\" ${KAFKA_CONFIG_PATH}"
    fi

    ### Zookeeper 설정
    [ ! -d ${KAFKA_PATH}/kafka.d/zookeeper ] && run_command "mkdir -p ${KAFKA_PATH}/kafka.d/zookeeper"

    if ! grep -q '^#dataDir=/tmp/zookeeper' ${KAFKA_ZOOKEEPER_PATH}; then
        run_command "cp -p ${KAFKA_ZOOKEEPER_PATH} ${KAFKA_ZOOKEEPER_PATH}_$(date +%y%m%d_%H%M%S)"

        run_command "sed -i 's/^dataDir=\/tmp\/zookeeper/#&/g' ${KAFKA_ZOOKEEPER_PATH}"
        run_command "sed -i \"/^#dataDir/a\dataDir=\${KAFKA_PATH}\/kafka.d\/zookeeper\" ${KAFKA_ZOOKEEPER_PATH}"
        
        [ ! $(grep -q 'tickTime' ${KAFKA_ZOOKEEPER_PATH}) ] && run_command "sed -i $'\$a\tickTime=2000' ${KAFKA_ZOOKEEPER_PATH}"
        [ ! $(grep -q 'initLimit' ${KAFKA_ZOOKEEPER_PATH}) ] && run_command "sed -i $'\$a\initLimit=10' ${KAFKA_ZOOKEEPER_PATH}"
        [ ! $(grep -q 'syncLimit' ${KAFKA_ZOOKEEPER_PATH}) ] && run_command "sed -i $'\$a\syncLimit=5' ${KAFKA_ZOOKEEPER_PATH}"

        ### --cluster-ips에 기재된 IP입력 순서를 기준으로 server id 할당, zookeeper/myid에 매칭된 ID 생성
        local _num=0
        for (( idx=0;idx<${#CLUSTER_IPS[@]};idx++ )); do
            _num=$(expr $idx + 1)
            [ "${CLUSTER_IPS[${idx}]}" == "${EXTERNAL_IP}" ] && run_command "echo \"${_num}\" >${KAFKA_PATH}/kafka.d/zookeeper/myid"
            run_command "sed -i $'\$a\server.${_num}=${CLUSTER_IPS[${idx}]}:2887:3887' ${KAFKA_ZOOKEEPER_PATH}"
        done
    fi
}


##################
### Kafak+Kraft 구성에 경우 standalone, cluster 2가지 방식을 지원 하고, Kraft UUID 값을 생성하기 위한 별도 함수를 추가
##################
function setup_kraft_storage() {        
        KRAFT_MODE="$1"
        KRAFT_UUID_PATH="${KAFKA_PATH}/kafka.d/kraft-uuid.tmp"

        ### Kraft 데이터 포맷
        if [ ! -d ${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs ]; then
            
            ### Krafta UUID에 main일 경우 UUID를 생성, main이 아닐 경우 --sub 옵션을 사용한 UUID에 값으로 설정 진행
            if [ "${KRAFT_UUID}" == "main" ]; then
                if [ ! -f ${KRAFT_UUID_PATH} ]; then
                    run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh random-uuid >\${KRAFT_UUID_PATH}"
                fi
                local KRAFT_UUID="$(cat ${KAFKA_PATH}/kafka.d/kafka-cluster-uuid.tmp)"

                ## Kraft mode에 따라 명령어 수행
                case ${KRAFT_MODE} in
                    "cluster" )
                        run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format -t ${KRAFT_UUID} -c ${KAFKA_PATH}/kafka.d/config/kraft/server.properties"
                    ;;
                    "standalone" )
                        run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format --standalone -t ${KRAFT_UUID} -c ${KAFKA_PATH}/kafka.d/config/kraft/reconfig-server.properties"
                    ;;
                esac
            
            elif [ -n "${KRAFT_UUID}" ]; then
                run_command "echo \"${KRAFT_UUID}\" >${KAFKA_PATH}/kafka.d/kafka-cluster-uuid.tmp"
                run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format -t ${KRAFT_UUID} -c ${KAFKA_PATH}/kafka.d/config/kraft/server.properties"
            fi
        fi
}

function setup_kraft_standalone() {
    KAFKA_CONFIG_PATH="${KAFKA_PATH}/kafka.d/config/kraft/reconfig-server.properties"

    ### Kraft를 사용하기 위한 Kafka 설정
    if ! grep -q '${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs' ${KAFKA_CONFIG_PATH}; then
        run_command "cp -p ${KAFKA_CONFIG_PATH} ${KAFKA_CONFIG_PATH}_$(date +%y%m%d_%H%M%S)"
        run_command "sed -i 's/^log.dirs/#&/g' ${KAFKA_CONFIG_PATH}"
        run_command "sed -i '/^#log.dirs/a\log.dirs=\${KAFKA_PATH}\/kafka.d\/logs\/kraft-combined-logs' ${KAFKA_CONFIG_PATH}"
    fi

    ## Kraft에 데이터 포맷
    local KRAFT_UUID_PATH="${KAFKA_PATH}/kafka.d/kraft-uuid.tmp"
    
    if [ ! -d ${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs ]; then
        if [ ! -f ${KRAFT_UUID_PATH} ]; then
            run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh random-uuid >\${KRAFT_UUID_PATH}"
        fi
        ### Kraft 데이터 포멧
        KRAFT_UUID="$(cat ${KAFKA_PATH}/kafka.d/kafka-cluster-uuid.tmp)"
        run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format --standalone -t ${KRAFT_UUID} -c ${KAFKA_PATH}/kafka.d/config/kraft/server.properties"
    fi
}

function setup_kraft_cluster() {
    KAFKA_CONFIG_PATH="${KAFKA_PATH}/kafka.d/config/kraft/server.properties"

    ### Kraft를 사용하기 위한 Kafka 설정
    if ! grep -q "controller.quorum.voters=.*.${EXTERNAL_IP}" ${KAFKA_CONFIG_PATH}; then
        run_command "cp -p ${KAFKA_CONFIG_PATH} ${KAFKA_CONFIG_PATH}_$(date +%y%m%d_%H%M%S)"

        ### --cluster-ips에 기재된 IP입력 순서를 기준으로 broker id 할당
        local _tmp_line=()
        local _num=0
        for (( idx=0;idx<${#CLUSTER_IPS[@]};idx++ )); do
            _num=$(expr $idx + 1)
            _tmp_line+=("${_num}@${CLUSTER_IPS[${idx}]}:9093")
            
            ### node id 수정
            if [ "${CLUSTER_IPS[${idx}]}" == "${EXTERNAL_IP}" ]; then
                if ! grep "^node.id=${_num}" ${KAFKA_CONFIG_PATH}; then
                    run_command "sed -i 's/^node.id/#&/g' ${KAFKA_CONFIG_PATH}"
                    run_command "sed -i \"/^#node.id/a\node.id=${_num}\" ${KAFKA_CONFIG_PATH}"
                fi
            fi
        done

        ### controller.quorum.voters 수정
        if ! grep -q "controller.quorum.voters=.*.${EXTERNAL_IP}:9093.*." ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^controller.quorum.voters=/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i \"/^#controller.quorum.voters=/a\controller.quorum.voters=$(echo "${_tmp_line[@]}" |sed 's/ /,/g')\" ${KAFKA_CONFIG_PATH}"
        fi

        ### listeners 수정
        if ! grep -q "^listeners=PLAINTEXT://${EXTERNAL_IP}:9092" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^listeners=PLAINTEXT/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i \"/^#listeners=PLAINTEXT/a\listeners=PLAINTEXT://${EXTERNAL_IP}:9092,CONTROLLER://${EXTERNAL_IP}:9093\" ${KAFKA_CONFIG_PATH}"
        fi

        ### advertised.listeners 수정
        if ! grep -q "^advertised.listeners=PLAINTEXT://${EXTERNAL_IP}:9092" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^advertised\.listeners=PLAINTEXT/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i \"/^#advertised\.listeners=PLAINTEXT/a\advertised.listeners=PLAINTEXT://${EXTERNAL_IP}:9092,CONTROLLER://${EXTERNAL_IP}:9093\" ${KAFKA_CONFIG_PATH}"
        fi

        ### log.dirs 수정
        if ! grep -q '${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs' ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^log.dirs/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#log.dirs/a\log.dirs=${KAFKA_PATH}\/kafka.d\/logs\/kraft-combined-logs' ${KAFKA_CONFIG_PATH}"
        fi
        
        ### num.partitions 수정
        if ! grep -q "num.partitions=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^num.partitions/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#num.partitions/a\num.partitions=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi
    
        ### offsets.topic.replication.factor 수정
        if ! grep -q "offsets.topic.replication.factor=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^offsets.topic.replication.factor/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#offsets.topic.replication.factor/a\offsets.topic.replication.factor=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi

        ### transaction.state.log.replication.factor 수정
        if ! grep -q "transaction.state.log.replication.factor=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^transaction.state.log.replication.factor/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#transaction.state.log.replication.factor/a\transaction.state.log.replication.factor=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi

        ### transaction.state.log.min.isr 수정
        if ! grep -q "transaction.state.log.min.isr=${#CLUSTER_IPS[@]}" ${KAFKA_CONFIG_PATH}; then
            run_command "sed -i 's/^transaction.state.log.min.isr/#&/g' ${KAFKA_CONFIG_PATH}"
            run_command "sed -i '/^#transaction.state.log.min.isr/a\transaction.state.log.min.isr=${#CLUSTER_IPS[@]}' ${KAFKA_CONFIG_PATH}"
        fi
    fi

    ## Kraft에 데이터 포맷
    local KRAFT_UUID_PATH="${KAFKA_PATH}/kafka.d/kraft-uuid.tmp"
    if [ ! -d ${KAFKA_PATH}/kafka.d/logs/kraft-combined-logs ]; then
        if [ "${KRAFT_MODE}" == "main" ]; then
            if [ ! -f ${KRAFT_UUID_PATH} ]; then
                run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh random-uuid >\${KRAFT_UUID_PATH}"
            fi
            ### Kraft 데이터 포멧
            KRAFT_UUID="$(cat ${KAFKA_PATH}/kafka.d/kafka-cluster-uuid.tmp)"
            run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format -t ${KRAFT_UUID} -c ${KAFKA_PATH}/kafka.d/config/kraft/server.properties"
        else
            if [ ! -f ${KRAFT_UUID_PATH} ]; then
                run_command "echo \"${KRAFT_UUID}\" >${KRAFT_UUID_PATH}"
            fi
            run_command "${KAFKA_PATH}/kafka.d/bin/kafka-storage.sh format -t ${KRAFT_UUID} -c ${KAFKA_PATH}/kafka.d/config/kraft/server.properties"
        fi
    fi
}

function setup_kafka_systemd() {
    if [ "${CLUSTER_MODE}" == "zookeeper" ]; then
        ### zookeeper systemd파일 생성
        if [ ! -f /usr/lib/systemd/system/zookeeper.service ]; then
            run_command "cat <<EOF >/usr/lib/systemd/system/zookeeper.service
[Unit]
Description=zookeeper
After=syslog.target
After=network.target

[Service]
Type=simple
Restart=on-failure
ExecStart=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/zookeeper-server-start.sh ${KAFKA_PATH}/kafka.d/config/zookeeper.properties'
ExecStop=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/zookeeper-server-stop.sh'

[Install]
WantedBy=multi-user.target
EOF"
        fi
        [ $? -eq 0 ] && run_command "systemctl daemon-reload"

        ### kafka systemd 파일 생성
        if [ ! -f /usr/lib/systemd/system/kafka.service ]; then
            run_command "cat <<EOF >/usr/lib/systemd/system/kafka.service
[Unit]
Description=kafka
After=syslog.target
After=network.target

[Service]
Type=simple
Restart=on-failure

KAFKA_OPTS="-Djava.net.preferIPv4Stack=True"

ExecStart=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/kafka-server-start.sh ${KAFKA_PATH}/kafka.d/config/server.properties'
ExecStop=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/kafka-server-stop.sh'

[Install]
WantedBy=multi-user.target
EOF"
        fi
        [ $? -eq 0 ] && run_command "systemctl daemon-reload"

    elif [ "${CLUSTER_MODE}" == "kraft" ]; then
        ### systemd 파일 생성
        if [ ! -f /usr/lib/systemd/system/kafka.service ]; then
            if [[ "${KRAFT_UUID}" == "main" || -n "${KRAFT_UUID}" ]]; then
                run_command "cat <<EOF >/usr/lib/systemd/system/kafka.service
[Unit]
Description=kafka
After=syslog.target
After=network.target

[Service]
Type=simple
Restart=on-failure
ExecStart=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/kafka-server-start.sh ${KAFKA_PATH}/kafka.d/config/kraft/server.properties'
ExecStop=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/kafka-server-stop.sh'

[Install]
WantedBy=multi-user.target
EOF"
            fi
            [ $? -eq 0 ] && run_command "systemctl daemon-reload"    
        fi

    elif [ "${KRAFT_UUID}" == "standalone" ]; then
        if [[ "${KRAFT_UUID}" == "main" || -n "${KRAFT_UUID}" ]]; then
            run_command "cat <<EOF >/usr/lib/systemd/system/kafka.service
[Unit]
Description=kafka
After=syslog.target
After=network.target

[Service]
Type=simple
Restart=on-failure
ExecStart=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/kafka-server-start.sh ${KAFKA_PATH}/kafka.d/config/kraft/reconfig-server.properties'
ExecStop=/bin/sh -c '${KAFKA_PATH}/kafka.d/bin/kafka-server-stop.sh'

[Install]
WantedBy=multi-user.target
EOF"
        fi
        [ $? -eq 0 ] && run_command "systemctl daemon-reload"
    fi
}

function help_usage() {
    echo -e "
${UWhite}Usage${ResetCl}: $0 [-i | -r] --app-dir ${IWhite}<KAFKA_PATH>${ResetCl}
                        [--cluster-mode] [--cluster-ips] [--main] [--running] [--verbose]

${UWhite}Positional arguments${ResetCl}:
--kafka-dir ${IWhite}<KAFKA_PATH>${ResetCl} --cluster-mode<
                  Kafka download, application path
                  ex) --kafka-dir /APP -> KAFKA_PATH="/APP/kafka.d"

--cluster-mode ${IWhite}<CLUSTER_MODE>${ResetCl}
                  Cluster mode chooise [ standalone, zookeeper, kraft ]
                  * using mode 'zookeeper' '--main, --sub' options is not used.

${UWhite}Options${ResetCl}:
-h, --help        Show this hel message and exit
-i                Install binaray kafka
-r                Remove binaray kafka

--cluster-ips ${IWhite}<KAFKA_PATH>${ResetCl}
                  Kafka with Kraft cluster ips (Ex. "192.168.0.1,192.168.0.2...")
                  Not using option default to Standalone mode
--main            
                  If use the '--cluster-ips' option, add it on the node where server want to create kraft UUID.
--sub         ${IWhite}<KRAFT_UUID>${ResetCl}
                  Put the UUID value assigned from '--main'
--running
                  When the Kafka setup is complete, The service will running.
--verbose
                  Prints in more detail about the script.
"
    exit 0
}

function remove_kafka() {
    ps -ef |grep 
}

function set_opts() {
    arguments=$(getopt --options irh \
    --longoptions help,kafka-dir:,cluster-ips:,cluster-mode:,main,sub:,running,verbose \
    --name $(basename $0) \
    -- "$@")

    KAFKA_ACTIVE=1
    DEBUG_MODE="no"
    CLUSTER_MODE=""
    CLUSTER_IPS=()
    eval set -- "${arguments}"
    # while true; do
    while [[ "$1" != "" ]]; do
        case "$1" in
            -h | --help ) help_usage    ;;
            -i ) MODE="install" ; shift ;;
            -r ) MODE="remove"  ; shift ;;
            --kafka-dir      ) KAFKA_PATH="$2"    ; shift 2 ;;
            --cluster-mode   ) CLUSTER_MODE="$2"  ; shift 2 ;;
            --cluster-ips    )
                IFS=',' read -r -a CLUSTER_IPS <<< "$2"
                #read -r -a CLUSTER_IPS <<< "$2"
                shift 2
            ;;
            --main        ) export KRAFT_UUID="main"  ; shift   ;;
            --sub         ) export KRAFT_UUID="$2"    ; shift 2 ;;
            --running     ) export KAFKA_ACTIVE=0     ; shift   ;;
            --verbose     ) export DEBUG_MODE="yes"   ; shift   ;;
            -- ) shift ; break ;;
            *  ) help_usage ;;
        esac
    done

    if [ ! -n ${KAFKA_PATH} ]; then
        printf "${Red}--kafka-dir option NULL.${ResetCl}\n"
        help_usage
    fi
    shift $((OPTIND - 1))
}

main() {
    [ $# -eq 0 ] && help_usage
    set_opts "$@"

    ### Kafka에 필요한 Java가 설치 유무를 확인한다.
    if ! $(javac --version |grep -Eq '8|11|17'); then
        logging "ERROR" "Supported Java version 8,11,17, please check java."
        exit 1 
    fi

    ### CLUSTER_MODE가 standalone이 아니라면 CLUSTER_IPS에 입력된 값을 확인한다.
    if [ "${CLUSTER_MODE}" != "standalone" ]; then
        EXTERNAL_IP=$(ip route get $(ip route |awk '/default/ {print $3}') |awk -F'src ' 'NR==1{split($2,a," "); print a[1]}')
        if [ ${#CLUSTER_IPS[@]} -le 1 ]; then
            logging "ERROR" "You must enter at least two --cluster-ips list element."
            exit 1
        fi

        if ! $(printf '%s\n' "${CLUSTER_IPS[@]}" |grep -q "${EXTERNAL_IP}"); then
            logging "ERROR" "--cluster-ips list is not include server ip."
            exit 1
        fi
    fi

    case ${MODE} in
        "install" )
            install_kafka
            if [ $? -eq 0 ]; then
                case ${CLUSTER_MODE} in
                    "zookeeper" )
                        setup_zookeeper_cluster
                    ;;
                    "kraft" )
                        setup_kraft_cluster
                    ;;
                    "standalone" )
                        setup_kraft_standalone
                    ;;
                esac

                ### Setup이 모두 완료되었다면, systemd 파일을 생성
                [ $? -eq 0 ] && setup_kafka_systemd

                if [ $? -eq 0 ]; then
                    if [ ${KAFKA_ACTIVE} -eq 0 ]; then
                        case ${CLUSTER_MODE} in
                        "zookeeper" )
                            run_command "systemctl start zookeeper"
                            logging_message "INFO" "The service will operate only when Zookeeper is enabled on another all sub node."
                            sleep 3
                            if $(jps |grep -iq 'quorum'); then
                                run_command "systemctl start kafka"
                                sleep 3
                                if $(jps |grep -iq 'kafka'); then
                                    logging "INFO" "Install completed."
                                    exit 0
                                else
                                    logging "ERROR" "Running fail kafka"
                                    exit 1
                                fi
                            else
                                logging "ERROR" "Running fail zookeeper"
                            fi
                        ;;
                        "kraft" )
                            setup_kraft_cluster
                            if [ $? -eq 0 ]; then
                                sleep 3
                                if $(jps |grep -iq 'kafka'); then
                                    logging "INFO" "Install completed."
                                    exit 0
                                else
                                    logging "ERROR" "Running fail kafka"
                                    exit 1
                                fi
                            else
                                exit 1
                            fi    
                        ;;
                        "standalone" )
                            setup_kraft_standalone
                            if [ $? -eq 0 ]; then
                                sleep 3
                                if $(jps |grep -iq 'kafka'); then
                                    logging "INFO" "Install completed."
                                    exit 0
                                else
                                    logging "ERROR" "Running fail kafka"
                                    exit 1
                                fi
                            else
                                exit 1
                            fi    
                        ;;
                        esac
                    else
                        logging "INFO" "The installation is complete, please perform the command below."
                        logging "INFO" "systemctl start kafka && jps |grep -i kafka"
                    fi
                else
                    logging "ERROR" "Setup fail kafka."
                    exit 1
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