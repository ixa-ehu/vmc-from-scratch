#!/bin/sh
/usr/bin/supervisorctl stop storm-ui
/usr/bin/supervisorctl stop storm-nimbus
/usr/bin/supervisorctl stop rabbitmq
/usr/bin/supervisorctl stop zookeeper
