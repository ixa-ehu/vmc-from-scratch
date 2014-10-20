import "create-hosts-file.pp"
import "install-zookeeper.pp"
import "install-kafka.pp"
import "install-storm.pp"
import "create-boss-start-script.pp"
import "create-boss-stop-script.pp"
import "create-worker-start-script.pp"
import "create-worker-stop-script.pp"
import "create-boss-supervisord-conf.pp"
import "create-worker-supervisord-conf.pp"

node '_BOSS_NAME_' {
  
  include install-zookeeper
  include install-kafka
  include start-boss-script

}

include create-hosts-file
include install-storm
