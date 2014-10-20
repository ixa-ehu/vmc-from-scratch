#!/bin/sh

/home/newsreader/update_nlp_components_boss.sh
pdsh -w _WORKER_NAME_[0-_NUM_NODES_] /home/newsreader/update_nlp_components_worker.sh
puppet agent --test
pdsh -w _WORKER_NAME_[0-_NUM_NODES_] puppet agent --test


sleep 30
su - newsreader -c 'cd /home/newsreader/opt/topologies_cluster; /opt/storm/bin/storm jar newsreader-pipe-topology.jar newsreader.pipe.topology.Main topology.conf newsreader_pipeline'
