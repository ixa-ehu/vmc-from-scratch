class run-kafka () {

  require install-kafka
  require run-zookeeper
  require create-boss-supervisord-conf
  
  exec { 'run-kafka':

    command => "/usr/bin/supervisorctl start kafka",
    unless => "/opt/bin/isrunning.sh kafka"
    
  }

}
