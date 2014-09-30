import 'wget.pp'


class install-kafka () {

  $user = 'kafka'
  $group = 'kafka'


  group { 'kafka-group':
    ensure => present,
    name => $group,
  }

  user { 'kafka-user':
    ensure => present,
    name => $user,
    gid => $group,
    home => "/home/$user",
    managehome => true,
    shell => '/bin/bash',
    require => Group['kafka-group'],
  }
  
  wget { 'download-kafka':
    url => 'http://ixa2.si.ehu.es/newsreader_storm_resources/kafka_2.10-0.8.1.1.tgz',
    creates => '/tmp/kafka_2.10-0.8.1.1.tgz',
  }

  exec { 'unzip-kafka':
    command => '/bin/tar xfz /tmp/kafka_2.10-0.8.1.1.tgz -C /opt',
    require => Wget['download-kafka'],
    creates => '/opt/kafka_2.10-0.8.1.1',
  }

  file { 'kafka-chown':
    ensure => directory,
    name => '/opt/kafka_2.10-0.8.1.1',
    owner => $user,
    group => $group,
    recurse => true,
    require => Exec['unzip-kafka'], 
  }

  file { 'kafka-data-dir':
    ensure => directory,
    name => '/var/lib/kafka',
    owner => $user,
    group => $group,
  } 

  file { 'kafka-log-dir':
    ensure => directory,
    name => '/var/log/kafka',
    owner => $user,
    group => $group,
  }

  file { 'kafka-dir-symlink':
    name => '/opt/kafka',
    ensure => link,
    target => '/opt/kafka_2.10-0.8.1.1',
    owner => $user,
    group => $group,
    require => File['kafka-chown'],
  }

  file { ['/etc/kafka', '/etc/kafka/config']:
    ensure => directory,
    owner => $user,
    group => $group,
  }
  
  file { 'kafka-conf':
    ensure => file,
    name => '/etc/kafka/config/server.properties',
    owner => $user,
    group => $group,
    source => 'puppet:///conf_files/kafka_server.properties',
    require => File['/etc/kafka/config'],
  }

}
