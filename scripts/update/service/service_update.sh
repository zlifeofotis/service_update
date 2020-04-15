#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

. /etc/init.d/functions
. ./predefines

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:.
export JAVA_HOME=/usr/java/latest
export CLASSPATH=.:$JAVA_HOME
export PATH=$PATH:$JAVA_HOME/bin:$JAVA_HOME/jre/bin
export CLASSPATH=.:$JAVA_HOME/lib:$CLASSPATH

BACKUP_SUFFIX=`date +%Y%m%d%H%M%S`
BACKUP_DIR=/backup/update
SERVER_LIST=../../../ip/new_service.lst
LIST_TMP=./list.tmp
ZIP_FILE=$1

if ! [[ ${ZIP_FILE} =~ .*\.zip ]] ; then
    printf $RED
    printf  "Usage:\n"
    printf  "\t$0 <zip filename in current path>\n"
    printf $END
    exit 101
fi
if ! [ -a ${ZIP_FILE} ] ; then
    printf $RED
    printf "${ZIP_FILE} does not exist!\n"
    printf $END
    exit 102
fi

pre_prompt

printf $GRE
while true
do
    read -p "请输入待更新服务的编号: " service_num1 
    read -p "请再次输入待更新服务的编号: " service_num2
    if [[ "${service_num1}" == "${service_num2}" ]] ; then
        service_num=$service_num1
        break
    fi
done
printf $END

if [ -z "${service_array[${service_num}]}" ] ; then
    echo -e "\n${RED}-----------非法编号----------${END}\n"
    exit 100
fi

echo -e "\n${RED}选择更新的服务是: ${service_array[${service_num}]}${END}\n" 
read -n 1 -p "继续请按任意键，退出按CTRL+C"
echo ""

echo -n "" > ${LIST_TMP}
for data in `cat ${SERVER_LIST} | sed 's/ //g'| grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -v -E "^#"`
do
    tmp=`ssh -o ConnectTimeout=1 root@${data} ps -ef | grep ${service_array[${service_num}]} | grep -v -E "\.sh|\.log|grep" | sed 's/\.jar/|/g' | awk -F\| '{print $(NF-1)}' | awk '{print $NF}'`
    if [ -n "${tmp}" ] ; then
        echo -n "${data}|"  >> ${LIST_TMP}
        echo "$(dirname $(echo ${tmp} | awk '{print $NF}'))" >> ${LIST_TMP}
    fi
done

for data in `cat ${LIST_TMP} | sed 's/ //g'| grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | grep -v -E "^#"`
do
    eval `echo $data | awk -F '|' '{print "ip_per="$1,"service_dir="$2}'`
    ip_per=$ip_per
    service_dir=$service_dir
    start_prog=./start.sh
    stop_prog=./stop.sh
    backup_file=${BACKUP_DIR}/${service_array[${service_num}]}_${BACKUP_SUFFIX}.tgz

    echo -e "\n--------ENV---------\n"
    echo -e ip_per=$ip_per
    echo -e service_dir=$service_dir
    echo -e backup_file=$backup_file
    echo -e start_prog=$start_prog
    echo -e stop_prog=$stop_prog
    echo -e ZIP_FILE=${ZIP_FILE}
    echo -e "\n-------END-ENV------\n"

    sleep 2

    scp ${ZIP_FILE} root@${ip_per}:${service_dir}/
    ssh -T root@${ip_per} << END
        cd ${service_dir}
        tar -zcvf $backup_file config lib *.jar *.yml
        unzip -o ${ZIP_FILE} 
        sh ${stop_prog}
        exit 0
END
done
echo ""
action "--------------service updated--------------" /bin/true

