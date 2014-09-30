#!/bin/sh
su - newsreader -c 'rsync -avz --delete -e "ssh" newsreader@_BOSS_NAME_:/home/newsreader/components/* /home/newsreader/components'
su - newsreader -c 'rsync -avz --delete -e "ssh" newsreader@_BOSS_NAME_:/home/newsreader/opt/* /home/newsreader/opt'
