#!/bin/bash

rflag=false
while getopts ":l:" opt; do
  case $opt in
      l)
	  rflag=true;
	  if [ $OPTARG = "en" ]; then
	      lang="en"
	  elif [ $OPTARG = "es" ]; then
	      lang="es"
	  fi
	  ;;
      \?)
	  echo "Invalid option -$OPTARG" >&2
	  ;;
  esac
done

if [ -z $lang ]; then
    echo "usage: sh init_system.sh -l {en|es}"
    exit
fi


# install NLP components on boss
chmod 600 /etc/master_rsync_secret
chown newsreader:newsreader /etc/master_rsync_secret
mkdir /home/newsreader/opt
chown newsreader:newsreader /home/newsreader/opt
mkdir /home/newsreader/components
chown newsreader:newsreader /home/newsreader/components
su -c "/home/newsreader/update_nlp_components_boss.sh -l $lang" newsreader
# install NLP components on worker
pdsh -w _WORKER_NAME_ /home/newsreader/update_nlp_components_worker.sh
# install and configure software using puppet on boss
puppet agent --test
# install and configure software using puppet on worker
pdsh -w _WORKER_NAME_ puppet agent --test
# configure puppet agent to start on boot, both on boss and worker
/sbin/chkconfig puppet on
pdsh -w _WORKER_NAME_ /sbin/chkconfig puppet on
