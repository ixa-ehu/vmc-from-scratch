
class create-boss-scripts () {

  file { '/etc/rc0.d/K01boss_servers':
    ensure => 'link',
    target => '/home/newsreader/opt/init.d/boss_servers',
  }

  file { '/etc/rc6.d/K01boss_servers':
    ensure => 'link',
    target => '/home/newsreader/opt/init.d/boss_servers',
  }

  file { 'opt-bin-dir':
    name => '/opt/bin',
    ensure => 'directory',
    owner => root,
    group => root,
  }
  
  file {'is-running':
    path    => '/opt/bin/isrunning.sh',
    ensure  => present,
    mode    => 0755,
    source => 'puppet:///conf_files/isrunning.sh',
  }

  file {'is-running-zookeeper':
    path    => '/opt/bin/isrunning_zookeeper.sh',
    ensure  => present,
    mode    => 0755,
    source => 'puppet:///conf_files/isrunning_zookeeper.sh',
  }
  
}
