#!/bin/bash

# 참조 blog
# https://velog.io/@mnetna/X-PACK-%EC%8B%9C%ED%81%90%EB%A6%AC%ED%8B%B0-%EB%AC%B4%EB%A3%8C-%EA%B8%B0%EB%8A%A5-%EC%82%AC%EC%9A%A9
# https://blog.binarynum.com/62
# https://jjeong.tistory.com/1433
# https://github.com/elastic/elasticsearch/blob/main/distribution/packages/src/common/systemd/elasticsearch.service
# https://velog.io/@91savage/ELK-Stack-Elasticsearch-Logstash-Kibana-debian-%EC%84%A4%EC%B9%98
# https://ploz.tistory.com/entry/logstash-elasticsearch-cluster%EC%97%90-logstash-%EB%B6%99%EC%97%AC%EB%B3%B4%EA%B8%B0SSL-%ED%8F%AC%ED%95%A8

#!/bin/bash
Color_Off="\033[0m"
Red="\033[0;31m"
Green="\033[0;32m"
Yellow="\033[0;33m"
Cyan="\033[0;36m"

function run_command() {
    command=$@
    log_message "CMD" "$@"    
    eval "${command}" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_message "OK"
        return 0
    else
        log_message "FAIL"
        return 1
    fi
}

function log_message() {
    cmd_log="tee -a ${SCRIPT_LOG}/script_${TODAY}.log"
    run_today=$(date "+%y%m%d")
    run_time=$(date "+%H:%M:%S.%3N")
  
    log_time="${run_today} ${run_time}"
    log_type=$1
    log_msg=$2

    case ${log_type} in
        "CMD"   ) printf "%s | %-*s | %s\n" "[${log_time}]" 3 "${log_type}" "${log_msg}"                         ;;
        "OK"    ) printf "%s | ${Green}%-*s${Color_Off} | %s\n" "[${log_time}]" 3 "${log_type}" "+- command ok." ;;
        "FAIL"  ) printf "%s | ${Red}%-*s${Color_Off} | %s\n" "[${log_time}]" 3 "${log_type}" "+- command fail." ;;
        "INFO"  ) printf "%s | %-*s | %s\n" "[${log_time}]" 3 "${log_type}" "${log_msg}"                         ;;
        "WARR"  ) printf "%s | ${Yellow}%-*s${Color_Off} | %s\n" "[${log_time}]" 3 "${log_type}" "${log_msg}"    ;;
        "SKIP"  ) printf "%s | ${Cyan}%-*s${Color_Off} | %s\n" "[${log_time}]" 3 "${log_type}" "${log_msg}"      ;;
        "ERROR" ) printf "%s | ${Red}%-*s${Color_Off} | %s\n" "[${log_time}]" 3 "${log_type}" "${log_msg}"       ;;
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
--svr-url  [ STRING ]     : ELK Service URL (Ex: elk.localhost.com)
-p, --path [ STRING ]     : ELK Path
-v, --ver  [  INT   ]     : ELK Version
EOF
    exit 0
}

function set_opts() {
    arguments=$(getopt --options u:s:p:v:hir \
    --longoptions user:,svr:,svr-url:,path:,ver:,help,install,remove \
    --name $(basename $0) \
    -- "$@")

    eval set -- "${arguments}"
    while true; do
        case "$1" in
            -i | --install  ) MODE="install"; shift   ;;
            -r | --remove   ) MODE="remove" ; shift   ;;
            -u | --user     ) ELK_USER=$2   ; shift 2 ;;
            -s | --svr      ) ELK_SVR=$2    ; shift 2 ;;
            --svr-url       ) ELK_URL=$2    ; shift 2 ;;
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

function setup_dir() {
    if [ ! -d ${ELK_PATH}/tools/pkgs ]; then
        run_command "mkdir -p ${ELK_PATH}/tools/pkgs"
    fi
}

function download_pkgs() {
    _RE="false"

    for _SVC in elasticsearch logstash kibana; do
        if [[ -f ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz ]] && [[ ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512 ]]; then
            while true; do
                read -p "exisit file ${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.
U wnat to re-create? (y/N) " _ANSWER
                case ${_ANSWER} in
                    [Yy] | [Yy][Ee][Ss] ) _RE="true" ; break                    ;;
                    [Nn] | [Nn][Oo]     ) log_message "INFO" "Script stop" ; exit 0 ;;
                    *                   ) log_message "WARR" "input Y or N"         ;;
                esac
            done
        fi

        if [ ${_RE} == "true" ]; then
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.org"
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512 ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512.org"
            run_command "rm -f ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz ${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512"
        fi

        run_command "curl -s https://artifacts.elastic.co/downloads/${_SVC}/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz >${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz"
        run_command "curl -s https://artifacts.elastic.co/downloads/${_SVC}/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512 >${ELK_PATH}/tools/pkgs/${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512"
        run_command "cd ${ELK_PATH}/tools/pkgs"

        run_command "shasum -a 512 -qc ${_SVC}-${ELK_VER}-linux-x86_64.tar.gz.sha512"
        if [ $? -eq 0 ]; then
            if [ ! -d ${ELK_PATH}/${_SVC}-${ELK_VER} ]; then
                run_command "tar -zxf ${_SVC}-${ELK_VER}-linux-x86_64.tar.gz -C ${ELK_PATH}/."
                run_command "cd ${ELK_PATH}"
            else
                log_message "SKIP" "Already install ${ELK_PATH}/${_SVC}-${ELK_VER}"
                continue
            fi

            if [ ! -f ${ELK_PATH}/${_SVC} ]; then
                run_command "cd ${ELK_PATH}"
                run_command "ln -s ./${_SVC}-${ELK_VER} ${_SVC}"
            else
                log_message "WARR" "Already ${ELK_PATH}/${_SVC}, so Change new [ ${_SVC}-${ELK_VER} ]"
                run_command "ln -Tfs ${ELK_PATH}/${_SVC}-${ELK_VER} ${_SVC}"
            fi
    
            log_message "INFO" "Sucess Install ${_SVC}"
        else
            log_message "ERROR" "Download error ${_SVC}-${ELK_VER}"
            exit 1
        fi
    done
}

function setup_ssl_root() {
    _RE="false"

    if [ -f ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip ]; then
        while true; do
            read -p "exisit file ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip.
U wnat to re-create? (y/N) " _ANSWER
            case ${_ANSWER} in
                [Yy] | [Yy][Ee][Ss] ) _RE="true" ; break                    ;;
                [Nn] | [Nn][Oo]     ) log_message "INFO" "Script stop" ; exit 0 ;;
                *                   ) log_message "WARR" "input Y or N"         ;;
            esac
        done
    fi

    if [ ${_RE} == "true" ]; then
        run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip.org"
        run_command "rm -f ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip"
        
        if [ -d ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root ]; then
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.org"
            run_command "rm -rf ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root"
        fi

        for _SVC in elasticsearch logstash kibana; do
            if [ -d ${ELK_PATH}/${_SVC}/config/certs ]; then
                run_command "cp -rfp ${ELK_PATH}/${_SVC}/config/certs ${ELK_PATH}/${_SVC}/config/certs.org"
                run_command "rm -rf ${ELK_PATH}/${_SVC}/config/certs"
            fi
        done
    fi

    for _SVC in elasticsearch logstash kibana; do
        if [ ! -d ${ELK_PATH}/${_SVC}/config/certs ]; then
            run_command "mkdir ${ELK_PATH}/${_SVC}/config/certs"
        fi
    done

    run_command "${ELK_PATH}/elasticsearch/bin/elasticsearch-certutil ca --silent --pem --days 365 --pass \"\" --out ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip"
    if [ $? -eq 0 ]; then
        run_command "unzip -d ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root.zip"
        for _SVC in elasticsearch logstash kibana; do
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root/* ${ELK_PATH}/${_SVC}/config/certs/."
        done
    else
        log_message "ERROR" "Create fail root-ca."
        exit 1
    fi

    if [ -f ${ELK_PATH}/tools/pkgs/${ELK_SVR}-instances.yml ]; then
        if [ ${_RE} == "true" ]; then
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-instances.yml ${ELK_PATH}/tools/pkgs/${ELK_SVR}-instances.yml.org"
            run_command "rm -f ${ELK_PATH}/tools/pkgs/${ELK_SVR}-instances.yml"
        fi
    fi
    run_command "cat <<EOF >${ELK_PATH}/tools/pkgs/${ELK_SVR}-instances.yml
instances:
    - name: 'instances'
      dns: [ '${ELK_SVR}', '${ELK_URL}' ]
EOF"
}

function setup_ssl_instance() {
    _RE="false"

    if [ -f ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip ]; then
        while true; do
            read -p "exisit file ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip.
U wnat to re-create? (y/N) " _ANSWER
            case ${_ANSWER} in
                [Yy] | [Yy][Ee][Ss] ) _RE="true" ; break                    ;;
                [Nn] | [Nn][Oo]     ) log_message "INFO" "Script stop" ; exit 0 ;;
                *                   ) log_message "WARR" "input Y or N"         ;;
            esac
        done
    fi

    if [ ${_RE} == "true" ]; then
        run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip.org"
        run_command "rm -f ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip"
        
        if [ -d ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances ]; then
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.org"
            run_command "rm -rf ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances"
        fi
    fi

    run_command "${ELK_PATH}/elasticsearch/bin/elasticsearch-certutil cert --silent --pem --ca-cert ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root/ca/ca.crt --ca-key ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-root/ca/ca.key --in ${ELK_PATH}/tools/pkgs/${ELK_SVR}-instances.yml --out ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip"
    if [ $? -eq 0 ]; then
        run_command "unzip -d ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances.zip"
        for _SVC in elasticsearch logstash kibana; do        
            run_command "cp -rfp ${ELK_PATH}/tools/pkgs/${ELK_SVR}-certs-instances/* ${ELK_PATH}/${_SVC}/config/certs/."
        done
    else
        log_message "ERROR" "Create fail instance-ca."
        exit 1
    fi
}

function setup_config() {
    _RE="false"
    _SVC=$1
    if [ -z ${_SVC} ]; then
        log_message "ERROR" "no arguments [set_config]."
        exit 1
    fi

    if [[ -f ${ELK_PATH}/${_SVC}/config/${_SVC}.yml ]] && [[ -f ${ELK_PATH}/${_SVC}/config/${_SVC}.yml.org ]]; then
        while true; do
            read -p "exisit file ${ELK_PATH}/${_SVC}/config/${_SVC}.yml.
U wnat to re-create? (y/N) " _ANSWER
            case ${_ANSWER} in
                [Yy] | [Yy][Ee][Ss] ) _RE="true" ; break                    ;;
                [Nn] | [Nn][Oo]     ) log_message "INFO" "Script stop" ; exit 0 ;;
                *                   ) log_message "WARR" "input Y or N"         ;;
            esac
        done
    fi

    if [ ${_RE} == "true" ]; then
        run_command "cp -rfp ${ELK_PATH}/${_SVC}/config/${_SVC}.yml ${ELK_PATH}/${_SVC}/config/${_SVC}.yml.org"
        run_command "rm -f ${ELK_PATH}/${_SVC}/config/${_SVC}.yml"
    fi

    run_command "cp ${ELK_PATH}/${_SVC}/config/${_SVC}.yml ${ELK_PATH}/${_SVC}/config/${_SVC}.yml.org"

    case ${_SVC} in
        elasticsearch )
            run_command "mkdir ${ELK_PATH}/elasticsearch/data"
            run_command "cat <<EOF >${ELK_PATH}/elasticsearch/config/elasticsearch.yml
cluster.name: ${ELK_SVR}
node.name: ${ELK_SVR}
path.data: ${ELK_PATH}/elasticsearch/data
path.logs: ${ELK_PATH}/elasticsearch/logs
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node

xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.key: certs/instances/instances.key
xpack.security.transport.ssl.certificate: certs/instances/instances.crt
xpack.security.transport.ssl.certificate_authorities: certs/ca/ca.crt

xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.key: certs/instances/instances.key
xpack.security.http.ssl.certificate: certs/instances/instances.crt
xpack.security.http.ssl.certificate_authorities: certs/ca/ca.crt
EOF"
        ;;
        kibana )
            _KIBANA_PASSWORD=$(awk -F'=' '/kibana_system =/ {print $2}' ${ELK_PATH}/elasticsearch/config/${ELK_SVR}_pass.temp |tr -d ' ')
            run_command "cat <<EOF >${ELK_PATH}/kibana/config/kibana.yml
server.name: ${ELK_SVR}
server.host: 0.0.0.0
server.port: 5601
server.publicBaseUrl: \"https://${ELK_URL}:5601\"

path.data: ${ELK_PATH}/kibana/data
pid.file: ${ELK_PATH}/kibana/data/kibana.pid

logging.root.level: info
logging.appenders.default:
    type: file
    fileName: ${ELK_PATH}/kibana/logs/kibana.log
    layout:
        type: json

server.ssl.enabled: true
server.ssl.certificate: ${ELK_PATH}/kibana/config/certs/instances/instances.crt
server.ssl.key: ${ELK_PATH}/kibana/config/certs/instances/instances.key

elasticsearch.hosts: https://${ELK_URL}:9200
elasticsearch.username: kibana_system
elasticsearch.password: ${_KIBANA_PASSWORD}
elasticsearch.ssl.certificateAuthorities: ${ELK_PATH}/kibana/config/certs/ca/ca.crt
EOF"
    ;;

    logstash )
        ELASTIC_PASSWORD=$(awk -F'=' '/elastic =/ {print $2}' ${ELK_PATH}/elasticsearch/config/${ELK_SVR}_pass.temp |tr -d ' ')
        if [ ! -d ${ELK_PATH}/logstash/conf.d ]; then
            run_command "mkdir ${ELK_PATH}/logstash/conf.d"
        fi
        
        run_command "cat <<EOF >${ELK_PATH}/logstash/config/logstash.yml
node.name: ${ELK_SVR}
path.config: ${ELK_PATH}/logstash/conf.d/*.conf
path.data: ${ELK_PATH}/logstash/data
path.logs: ${ELK_PATH}/logstash/logs

xpack.monitoring.enabled: true
xpack.monitoring.elasticsearch.username: elastic
xpack.monitoring.elasticsearch.password: ${ELASTIC_PASSWORD}
xpack.monitoring.elasticsearch.hosts: https://${ELK_URL}:9200

xpack.monitoring.elasticsearch.ssl.certificate_authority: ${ELK_PATH}/logstash/config/certs/ca/ca.crt
xpack.monitoring.elasticsearch.ssl.verification_mode: certificate
xpack.monitoring.elasticsearch.sniffing: false
xpack.monitoring.collection.interval: 10s
xpack.monitoring.collection.pipeline.details.enabled: true
EOF"
        if [ ! -f ${ELK_PATH}/logstash/conf.d/basic-logstash.conf ]; then
            run_command "cat <<EOF >${ELK_PATH}/logstash/conf.d/basic-logstash.conf
input {
    file {
        path            => \"/var/log/secure\"
        start_position  => beginning
    }
}

output {
    elasticsearch {
        index       => \"logstash-%{+YYYY.MM.dd}\"
        hosts       => \"https://${ELK_URL}:9200\"
        ssl         => true
        cacert      => \"${ELK_PATH}/logstash/config/certs/ca/ca.crt\"
        user        => \"elastic\"
        password    => \"${ELASTIC_PASSWORD}\"
    }
}
EOF"
        fi
    ;;
    esac
}

function setup_service() {
    _RE="false"
    _SVC=$1
    
    if [ -z ${_SVC} ]; then
        log_message "ERROR" "no arguments [set_config]."
        exit 1
    fi

    if [ -f /usr/lib/systemd/system/${_SVC}.service ]; then
        while true; do
            read -p "/usr/lib/systemd/system/${_SVC}.service.
U wnat to re-create? (y/N) " _ANSWER
            case ${_ANSWER} in
                [Yy] | [Yy][Ee][Ss] ) _RE="true" ; break                    ;;
                [Nn] | [Nn][Oo]     ) log_message "INFO" "Script stop" ; exit 0 ;;
                *                   ) log_message "WARR" "input Y or N"         ;;
            esac
        done
    fi

    if [ ${_RE} == "true" ]; then
        run_command "cp -rfp /usr/lib/systemd/system/${_SVC}.service /usr/lib/systemd/system/${_SVC}.service.org"
        run_command "rm -f /usr/lib/systemd/system/${_SVC}.service"
    fi

    _SCRIPT_DIR=$(dirname ${SCRIPT_PATH})
    run_command "cd ${_SCRIPT_DIR}"
    run_command "cp -fp ./${_SVC}.service.sample ./${_SVC}.service"
    run_command "sed -i \"s~ELK_PATH~${ELK_PATH}~g\" ./${_SVC}.service"
    run_command "sed -i \"s~ELK_USER~${ELK_USER}~g\" ./${_SVC}.service"
    run_command "cp -fp ./${_SVC}.service /usr/lib/systemd/system/${_SVC}.service"
    run_command "systemctl daemon-reload"
}

function setup_password() {
    _RE="false"

    if [ -f ${ELK_PATH}/elasticsearch/config/elk_pass.temp ]; then
        while true; do
            read -p "exisit file ${ELK_PATH}/elasticsearch/config/elk_pass.temp.
U wnat to re-create? (y/N) " _ANSWER
            case ${_ANSWER} in
                [Yy] | [Yy][Ee][Ss] ) _RE="true" ; break                    ;;
                [Nn] | [Nn][Oo]     ) log_message "INFO" "Script stop" ; exit 0 ;;
                *                   ) log_message "WARR" "input Y or N"         ;;
            esac
        done
    fi

    if [ ${_RE} == "true" ]; then
        run_command "cp -rfp ${ELK_PATH}/elasticsearch/config/elk_pass.temp ${ELK_PATH}/elasticsearch/config/elk_pass.temp.org"
        run_command "rm -f ${ELK_PATH}/elasticsearch/config/elk_pass.temp"
    fi

    run_command "chown -R ${ELK_USER}.${ELK_USER} ${ELK_PATH}"
    run_command "systemctl start elasticsearch"
    while true; do
        if netstat -anp |grep -q 9200; then
            break
        fi
    done

    run_command "su - ${ELK_USER} -c 'yes| ${ELK_PATH}/elasticsearch/bin/elasticsearch-setup-passwords auto -u \"https://${ELK_URL}:9200\" >${ELK_PATH}/elasticsearch/config/elk_pass.temp'"
    if [ $? -eq 0 ]; then
        log_message "INO" "Sucess elk password."
    elif [ $(echo $?) -eq 78 ]; then
        log_message "ERROR"  "keystore file is missing [ ${ELK_PATH}/elasticsearch/config/elasticsearch.keystore ]"
        exit 1
    else
        log_message "ERROR" "Fail auto password. Because Already been excuted once 'elasticsearch-auto-passwords auto'.\nPlease using elasticsearch-reset-password' or Delete Elasticsearch data."
        exit 1
    fi
}

function remove_service() {
    _SVC=$1
    
    if [[ -z ${_SVC} ]] || [[ -z ${ELK_PATH} ]]; then
        log_message "ERROR" "no arguments [set_config]."
        exit 1
    fi

    if ps -ef |grep ${_SVC} |grep -qv "grep"; then
        run_command "systemctl stop ${_SVC}"
    fi

    while true; do
        if ps -ef |grep ${_SVC} |grep -qv "grep"; then
            continue
        else
            break
        fi
    done

    if [ -f /usr/lib/systemd/system/${_SVC}.service ]; then
        run_command "rm -f /usr/lib/systemd/system/${_SVC}.service"
    fi

    run_command "systemctl daemon-reload"
    if [ ${_SVC} == "elasticsearch" ]; then
        run_command "rm -rf /tmp/elasticsearch-*"
    fi
    run_command "rm -rf ${ELK_PATH}/${_SVC}"
}

main() {
    SCRIPT_PATH=$(readlink -f $0)

    [ $# -eq 0 ] && help_message
    set_opts "$@"

    if [ ! -d ${ELK_PATH} ]; then
        log_message "ERROR" "Pleaase check path ${ELK_PATH}"
        exit 1
    else
        case ${MODE} in
            "install" )
                setup_dir
                download_pkgs
                setup_ssl_root
                setup_ssl_instance
                setup_config "elasticsearch"
                setup_service "elasticsearch"
                setup_password
                setup_config "kibana"
                setup_service "kibana"
                setup_config "logstash"
                setup_service "logstash"
                run_command "chown -R ${ELK_USER}.${ELK_USER} ${ELK_PATH}"
            ;;
            "remove"  )
                remove_service "kibana"
                remove_service "logstash"
                remove_service "elasticsearch"
                run_command "rm -rf ${ELK_PATH}"
            ;;
            *         ) help_message     ; exit 0 ;;
        esac
    fi
}
main $*