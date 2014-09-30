#!/bin/sh

puppet agent --test
pdsh -w _WORKER_NAME_[0-_NUM_NODES_] puppet agent --test
/home/newsreader/update_nlp_components_boss.sh
pdsh -w _WORKER_NAME_[0-_NUM_NODES_] chown newsreader:newsreader /home/newsreader/.ssh/known_hosts
pdsh -w _WORKER_NAME_[0-_NUM_NODES_] /home/newsreader/update_nlp_components_worker.sh
#pdsh -w _WORKER_NAME_[0-_NUM_NODES_] /home/newsreader/components/EHU-ned/run_spotlight_server.sh
su - zookeeper -c '/opt/zookeeper/bin/zkServer.sh start /etc/zookeeper/conf/zoo.cfg'
su - kafka -c '/opt/kafka/bin/kafka-server-start.sh /etc/kafka/config/server.properties &'
su - newsreader -c '/opt/storm/bin/storm nimbus &'
su - newsreader -c '/opt/storm/bin/storm ui &'
pdsh -w _WORKER_NAME_[0-_NUM_NODES_]  /opt/run_storm_supervisor.sh
sleep 10
su - newsreader -c 'cd /home/newsreader/opt/topologies_cluster; /opt/storm/bin/storm jar newsreader-pipe-topology.jar newsreader.pipe.topology.Main topology.conf newsreader_pipeline'
