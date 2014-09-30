import "wget.pp"


class install-jzmq () {

  package { 'jzmq-install':
    ensure => installed,
    provider => rpm,
    name => 'jzmq.x86_64',
    source => 'http://ixa2.si.ehu.es/newsreader_storm_resources/jzmq-2.1.0.el6.x86_64.rpm',
  }

}
