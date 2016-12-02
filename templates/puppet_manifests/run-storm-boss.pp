class run-storm-boss () {

  require install-storm
  require run-zookeeper
  require run-rabbitmq
  require create-boss-supervisord-conf
  
  exec { 'run-storm-boss-nimbus':

    command => "/usr/bin/supervisorctl start storm-nimbus",
    unless => "/opt/bin/isrunning.sh storm-nimbus"
    
  }
  ->
  exec { 'run-storm-boss-ui':

    command => "/usr/bin/supervisorctl start storm-ui",
    unless => "/opt/bin/isrunning.sh storm-ui"
    
  }

  
}
