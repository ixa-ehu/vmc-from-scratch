
class create-boss-supervisord-conf () {

  require install-zookeeper
  require install-kafka
  require install-storm
  
  file {'boss-supervisord-conf':
    path    => '/etc/supervisord.conf',
    ensure  => present,
    mode    => 0644,
    source => 'puppet:///conf_files/boss_supervisord.conf',
  }
  ->
  exec {'reload-supervisord':
    command => '/etc/init.d/supervisord restart',
  }

}
