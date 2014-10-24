class sync-time-worker () {

  exec { 'sync-time-worker':
    command => "/usr/sbin/ntpd -gq"
  }

}
