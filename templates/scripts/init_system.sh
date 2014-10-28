#!/bin/sh

# install NLP components on boss
/home/newsreader/update_nlp_components_boss.sh
# install NLP components on worker
pdsh -w _WORKER_NAME_ /home/newsreader/update_nlp_components_worker.sh
# install and configure software using puppet on boss
puppet agent --test
# install and configure software using puppet on worker
pdsh -w _WORKER_NAME_ puppet agent --test
# configure puppet agent to start on boot, both on boss and worker
/sbin/chkconfig puppet on
pdsh -w _WORKER_NAME_ /sbin/chkconfig puppet on
