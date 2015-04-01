#!/bin/bash

rflag=false
while getopts ":c:" opt; do
  case $opt in
      c)
	  rflag=true
	  numCpu=$OPTARG
	  ;;
      \?)
	  echo "Invalid option -$OPTARG" >&2
	  ;;
  esac
done

if [ ! $numCpu ]; then
    echo "usage: sh config_kafka_batch.sh -c numCPUs"
    exit
fi


echo "Killing topology..."
kill_topology.sh &> /dev/null
sudo supervisorctl stop flush-queue-daemon kafka storm-ui storm-nimbus zookeeper
sudo rm -rf /var/lib/kafka/*
sudo rm -rf /var/lib/zookeeper/*
sudo supervisorctl start zookeeper storm-nimbus storm-ui kafka flush-queue-daemon

/opt/kafka/bin/kafka-topics.sh --zookeeper localhost --create --topic input_queue --partitions $numCpu --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --zookeeper localhost --create --topic output_queue --partitions 1 --replication-factor 1
