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
    --ip   [ STRING ]  : Rundeck server ip
-h, --help             : Script Help
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options p:irh \
    --longoptions path:,ip:,help,install,remove \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"
    while true; do
        case "$1" in
            -i | --install  ) MODE="install"  ; shift   ;;
            -r | --remove   ) MODE="remove"   ; shift   ;;
            -p | --path     ) RDECK_BASE=$2   ; shift 2 ;;
                 --ip       ) REDCK_IP=$2     ; shift 2 ;;
            -h | --help     ) help_message              ;;            
            --              ) shift           ; break   ;;
            ?               ) help_message              ;;
        esac
    done

    shift $((OPTIND-1))
    [ -z ${RDECK_BASE} ] && help_msg
}

function install_rundeck() {
    _java_bin_path=$(command -v java)
    if [ ! -d ${RDECK_BASE} ]; then
        mkdir -p ${RDECK_BASE}
    else
        logging_message "SKIP" "Already ${RDECK_BASE}"
    fi

    run_command "wget https://packagecloud.io/pagerduty/rundeck/packages/java/org.rundeck/rundeck-5.8.0-20241205.war/artifacts/rundeck-5.8.0-20241205.war/download?distro_version_id=167 \
    -O ${RDECK_BASE}/rundeck-5.8.0-20241205.war"

    if [ ! -f ${RDECK_BASE}/env.cfg ]; then
        run_command "cat <<EOF >${RDECK_BASE}/env.cfg
##### > Rundeck enviroment
PATH=$PATH:${RDECK_BASE}/tools/bin
MANPATH=$MANPATH:${RDECK_BASE}/docs/man
EOF"
    else
        logging_message "SKIP" "Already create file ${REDECK_BASE}/env.cfg"
    fi

    if [ ${grep -q "${RDECK_BASE}/env.cfg" ${HOME}/.bash_profile} ]; then
        run_command "echo \"source ${RDECK_BASE}/env.cfg\" >>${HOME}/.bash_profile"
    fi

    if [ ! -f /etc/systemd/system/rundeck.service ]; then
        run_command "cat <<EOF >/etc/systemd/system/rundeck.service
[Unit]
Description=Rundeck

[Service]
Type=simple
SyslogLevel=debug
User=root
ExecStart=${_java_bin_path} -Xmx4g -Xms1g -XX:MaxMetaspaceSize=256m -jar ${RDECK_BASE}/rundeck-5.8.0-20241205.war
ExecStart=${_java_bin_path} -Xmx1024m -Xms256m -XX:MaxMetaspaceSize=256m -server -jar ${RDECK_BASE}/rundeck-5.8.0-20241205.war
KillSignal=SIGTERM
KillMode=mixed
WorkingDirectory=${RDECK_BASE}

LimitNOFILE=65535
LimitNPROC=65535
TasksMax=infinity
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=120
SyslogIdentifier=IRI
Restart=on-failure
RestartSec=120

[Install]
WantedBy=multi-user.target
EOF"
        run_command "source ${HOME}/.bash_profile"
        run_command "systemctl daemon-reload"
        run_command "systemctl start rundeck ; systemctl stop rundeck"
    else
        logging_message "SKIP" "Already create file /etc/systmed/system/rundeck.service"
    fi
}

function setup_rundeck_config() {
    if [ ${grep -q "grails.serverURL=http://${RDECK_IP}:4440" ${RDECK_BASE}/server/config/rundeck-config.properties} ]; then
        run_command "cp -p ${RDECK_BASE}/server/config/rundeck-config.properties ${RDECK_BASE}/server/config/rundeck-config.properties.bk_$(date +%y%m%d_%H%M%S)"
        run_command "sed -i 's/server.address/#&/g' ${RDECK_BASE}/server/config/rundeck-config.properties"
        run_command "sed -i '/^#server.address/a\server.address=0.0.0.0' ${RDECK_BASE}/server/config/rundeck-config.properties"
        run_command "sed -i 's/grails.serverURL/#&/g' ${RDECK_BASE}/server/config/rundeck-config.properties"
        run_command "sed -i '/^#grails.serverURL/a\grails.serverURL=http://${RDECK_IP}:4440' ${RDECK_BASE}/server/config/rundeck-config.properties"
    else
        logging_message "SKIP" "Already config file ${RDECK_BASE}/server/config/rundeck-config.properties"
    fi
}
function main() {
    [ $# -eq 0 ] && help_message
    set_opts "$@"

    case ${MODE} in
        "install" )
            install_rundeck
            if [ $? -eq 0 ]; then
                setup_rundeck_config
            else
                logging_message "ERROR" "Install rundeck failed/"
            fi
        ;;
        # "remove"  ) echo "remote"  ; exit 0 ;;
        # *         ) help_message     ; exit 0 ;;
    esac
}
main $*