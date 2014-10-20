class create-dbpedia-logdir () {

  $user = 'newsreader'
  $group = 'newsreader'

  file { 'dbpedia-logdir':
    ensure => directory,
    name => '/var/log/dbpedia',
    owner => $user,
    group => $group,
  }

}
