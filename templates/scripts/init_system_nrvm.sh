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
mkdir /var/run/srl-server
chown newsreader:newsreader /var/run/srl-server
su -c "/home/newsreader/update_nlp_components_boss.sh -l $lang" newsreader
# if dbpedia_disabled file is present disable it
if [ -f  /etc/nrvm_supervisord.conf ]; then
    cp /etc/nrvm_supervisord.conf /etc/supervisord.conf
    /usr/bin/supervisorctl update
elif [ -f  /etc/nrvm_supervisord.conf.dbpedia_disabled ]; then
    cp /etc/nrvm_supervisord.conf.dbpedia_disabled /etc/supervisord.conf
    /usr/bin/supervisorctl update
fi
