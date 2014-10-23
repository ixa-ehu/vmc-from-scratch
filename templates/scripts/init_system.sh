#!/bin/sh

/home/newsreader/update_nlp_components_boss.sh
pdsh -w _WORKER_NAME_ /home/newsreader/update_nlp_components_worker.sh
puppet agent --test
pdsh -w _WORKER_NAME_ puppet agent --test
pdsh -w _WORKER_NAME_ /sbin/chkconfig puppet on
