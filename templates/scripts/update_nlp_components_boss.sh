#!/bin/bash

extract_dir=/home/newsreader/
utils="ftp://ixa.si.ehu.es/utils.tar.bz2"
comp_en="ftp://ixa.si.ehu.es/components_en.tar.bz2"
comp_es="ftp://ixa.si.ehu.es/components_es.tar.bz2"

rflag=false
while getopts ":l:" opt; do
  case $opt in
      l)
	  rflag=true;
	  if [ $OPTARG = "en" ]; then
	      comp=$comp_en
	  elif [ $OPTARG = "es" ]; then
	      comp=$comp_es
	  fi
	  ;;
      \?)
	  echo "Invalid option -$OPTARG" >&2
	  ;;
  esac
done

if [ -z $comp ]; then
    echo "update_nlp_modules.sh -l {en|es}"
    exit
fi

wget --no-check-certificate -O - $utils | bunzip2 -c | tar xf - --directory $extract_dir
wget --no-check-certificate -O - $comp | bunzip2 -c | tar xf - --directory $extract_dir
