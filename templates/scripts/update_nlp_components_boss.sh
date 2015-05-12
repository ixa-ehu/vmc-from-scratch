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
    echo "usage: update_nlp_modules.sh -l {en|es}"
    exit
fi

rsync -av --port=3333 --delete --password-file=/etc/master_rsync_secret nrvm@_MASTER_IP_::newsreadervm_"$lang"_opt /home/newsreader/opt
rsync -av --port=3333 --delete --password-file=/etc/master_rsync_secret nrvm@_MASTER_IP_::newsreadervm_"$lang"_components /home/newsreader/components
