import "create-hosts-file.pp"
import "install-zookeeper.pp"
import "install-kafka.pp"
import "install-storm.pp"

node '_BOSS_NAME_' {
  
  include create-hosts-file
  include install-zookeeper
  include install-kafka
  include install-storm

}
