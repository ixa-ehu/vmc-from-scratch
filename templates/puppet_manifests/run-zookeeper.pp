class run-zookeeper () {

  require install-zookeeper
  require create-boss-supervisord-conf
  
  exec { 'run-zookeeper':

    command => "/usr/bin/supervisorctl start zookeeper",
    unless => "/opt/bin/isrunning.sh zookeeper"
    
  }

}
