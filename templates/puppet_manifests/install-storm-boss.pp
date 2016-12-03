import "install-storm.pp"


class install-storm-boss () {

  require install-storm
  
  file { 'storm-conf-boss':
    ensure => file,
    replace => 'no',
    name => '/opt/storm/conf/storm.yaml',
    owner => $user,
    group => $group,
    source => 'puppet:///conf_files/storm.boss.conf',
  }

}
