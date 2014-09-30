import "wget.pp"


class install-zeromq () {

  package { 'zeromq-install':
    ensure => installed,
    provider => rpm,
    name => 'zeromq-2.1.7-1.el6.x86_64',
    source => 'http://ixa2.si.ehu.es/newsreader_storm_resources/zeromq-2.1.7-1.el6.x86_64.rpm',
  }

}
