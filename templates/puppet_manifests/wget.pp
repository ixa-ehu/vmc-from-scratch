define wget ($url, $path = '/tmp', $creates) {

  if !defined(Package["wget"]) {
    package { "wget":
      name => 'wget',
      ensure => installed,
    }
  }
  
  exec { "download_$url":
    command => "/usr/bin/wget $url -P $path",
    creates => $creates,
    require => Package["wget"],
  }

}
