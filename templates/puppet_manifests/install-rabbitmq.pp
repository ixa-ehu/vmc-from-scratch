class install-rabbitmq () {
  
  package { 'rabbitmq-server':
    ensure => 'installed',
  }

}
