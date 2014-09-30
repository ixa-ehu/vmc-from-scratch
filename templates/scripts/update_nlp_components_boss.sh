#!/bin/sh
su - newsreader -c 'rsync -avz --delete -e "ssh -p2223" newsreader@_MASTER_IP_:/home/newsreader/components/* /home/newsreader/components'
su - newsreader -c 'rsync -avz --delete -e "ssh -p2223" newsreader@_MASTER_IP_:/home/newsreader/opt/* /home/newsreader/opt'
