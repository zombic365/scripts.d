#/bin/bash
KAFKA_PATH="/APP"
mkdir -p ${KAFKA_PATH}

### Kafka 파일 다운 및 기본 구성
wget https://dlcdn.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz -P ${KAFKA_PATH}/.
tar -zxf ${KAFKA_PATH}/kafka_2.13-3.9.0.tgz -C ${KAFKA_PATH}
cd ${KAFKA_PATH}
ln -s ./kafka_2.13-3.9.0 kafka.d

### kafka.d/bin 파일 환경변수로 등록
if ! grep -q 'kafka.d' ${HOME}/.bash_profile; then
    sed -i "/export PATH/i\PATH=\$PATH:${KAFKA_PATH}\/kafka.d\/bin" ${HOME}/.bash_profile
fi
source ~/.bash_profile

### kafka cluster에서 사용할 고유 UUID 생성
kafka-storage.sh random-uuid >${KAFKA_PATH}/kafka-cluster-uuid.tmp
KAFKA_CLUSTER_ID="$(cat ${KAFKA_PATH}/kafka-cluster-uuid.tmp)"

### kraft 로그 경로 변경
cp -p ${KAFKA_PATH}/config/kraft/reconfig-server.properties ${KAFKA_PATH}/config/kraft/reconfig-server.properties_$(date +%y%m%d_%H%M%S)
sed -i 's/^log.dirs/#&/g' ${KAFKA_PATH}/config/kraft/reconfig-server.properties
sed -i "/^#log.dirs/a\log.dirs=${KAFKA_PATH}\/kafka.d\/logs\/kraft-combined-logs" ${KAFKA_PATH}/config/kraft/reconfig-server.properties

### kafka 포맷
kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c ${KAFKA_PATH}/config/kraft/reconfig-server.properties

### systemd 파일 생성
if [ ! -f /usr/lib/systemd/system/kafka.service ]; then
    cat <<EOF >/usr/lib/systemd/system/kafka.service
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
EOF
    systemctl daemon-reload
    systemctl start kafka
fi

netstat -anp |grep 9092