#!/bin/bash

PASS_FILE="./test_pass.tmp"
# PASS_NAME_ARR=(
#     "MYSQL" "ADMIN" "RABBIT"
#     "KEYSTONE" "KEYSTONE_DB"
#     "PLACEMENT" "PLACEMENT_DB"
#     "GLANCE" "GLANCE_DB"
#     "NOVA" "NOVA_DB"
#     "NEUTRON" "NEUTRON_DB"
#     "METADATA_SECRET"
#     "CINDER"
#     "CINDER_DB"
# )

[ -f ${PASS_FILE} ] && printf "[%-4s] %s\n" ERR "already exsit file ${PASS_FILE}."; exit 1
function generate_password() {
    for _pass_name in ${PASS_NAME_ARR[@]}; do
        _pass_cmd=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')
        echo "${_pass_name}_PASS="${_pass_cmd}"" >>${PASS_FILE}
    done
}
generate_password