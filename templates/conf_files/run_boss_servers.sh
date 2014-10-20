#!/bin/sh
/usr/bin/supervisorctl start zookeeper
/usr/bin/supervisorctl start kafka
/usr/bin/supervisorctl start storm-nimbus
/usr/bin/supervisorctl start storm-ui
