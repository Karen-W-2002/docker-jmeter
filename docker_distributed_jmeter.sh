#!/bin/sh
#1
SUB_NET="172.18.0.0/16"
CLIENT_IP=172.18.0.23
declare -a SERVER_IPS=("172.18.0.101" "172.18.0.102" "172.18.0.103")
 
#2
timestamp=$(date +%Y%m%d_%H%M%S)
volume_path=$(pwd)/share_folder
jmeter_path=/mnt/jmeter
TEST_NET=jmeter-distributed-network
docker_image_name=jmeter-test1:5.4.3
test_plan_path_name=tests/test_plan_k6_test.jmx

#3
echo "Create testing network"
docker network create --subnet=$SUB_NET $TEST_NET

#4
echo "Create slave servers"
for IP_ADD in "${SERVER_IPS[@]}"
do
	docker run \
	-dit \
	--net $TEST_NET --ip $IP_ADD \
	-v "${volume_path}":${jmeter_path} \
	--rm \
	${docker_image_name} \
	-n -s \
	-Jserver.rmi.localport=60000 \
	-Jserver.rmi.ssl.keystore.file=${jmeter_path}/rmi_keystore.jks \
  -Djava.rmi.server.hostname=${IP_ADD} \
  -Djava.security.manager \
  -Djava.security.policy=${JMETER_HOME}/bin/java.policy \
  -Djmeter.home=${JMETER_HOME} \
	-j ${jmeter_path}/server/slave_${timestamp}_${IP_ADD:9:3}.log 
done

#5 
echo "Create master client and execute test"
docker run \
  --net $TEST_NET --ip $CLIENT_IP \
  -v "${volume_path}":${jmeter_path} \
  --rm \
  ${docker_image_name} \
  -n -X \
  -Jserver.rmi.ssl.keystore.file=${jmeter_path}/rmi_keystore.jks \
  -Djava.security.manager \
  -Djava.security.policy=${JMETER_HOME}/bin/java.policy \
  -Djmeter.home=${JMETER_HOME} \
  -t ${jmeter_path}/${test_plan_path_name} \
  -R $(echo $(printf ",%s" "${SERVER_IPS[@]}") | cut -c 2-) \
  -l ${jmeter_path}/client/result_${timestamp}.csv \
  -j ${jmeter_path}/client/jmeter_${timestamp}.log \
  -e -o ${jmeter_path}/client/html-report_${timestamp}
 
#6
docker network rm $TEST_NET
echo "Done"