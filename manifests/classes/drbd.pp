/*

== Class: drbd::base

Basic class which installs the drbd modules and tools, and enables the service
at boot time.

Usage:

  include drbd::base

*/
class drbd::base {

  case $operatingsystem {

    RedHat: {

      if ( ! $centos_mirror ) {
        $centos_mirror = "http://mirror.switch.ch/ftp/mirror/centos/"
      }

      yumrepo { "centos-extra-drbd":
        descr => "DRBD packages from Centos-extras for RHEL ${lsbmajdistrelease}",
        baseurl => "${centos_mirror}${operatingsystemrelease}/extras/${architecture}/",
        enabled => 1,
        gpgkey => "${centos_mirror}/RPM-GPG-KEY-CentOS-${lsbmajdistrelease}",
        gpgcheck => 1,
        includepkgs => "drbd83,kmod-drbd83,kmod-drbd83-xen",
      }

      if $virtual == "xenu" {
        $kmodpkg = "kmod-drbd83-xen"
      } else {
        $kmodpkg = "kmod-drbd83"
      }

      package { "drbd83":
        ensure  => present,
        alias   => "drbd",
        require => Yumrepo["centos-extra-drbd"],
      }

      package { $kmodpkg:
        ensure  => present,
        alias   => "drbd-module",
        require => Yumrepo["centos-extra-drbd"],
      }

    }

    Debian: {
      #TODO
    }
  }

  exec { "load drbd module":
    command => "modprobe drbd",
    creates => "/proc/drbd",
    require => Package["drbd-module"],
  }

  service { "drbd":
    ensure    => running,
    hasstatus => true,
    enable    => true,
    require   => [Package["drbd", "drbd-module"], Exec["load drbd module"]],
  }

  # Notifying the drbd service is definitely a bad idea. This exec will do the
  # same thing "service drbd reload" would do.
  exec { "reload drbd":
    command     => "drbdadm adjust all",
    refreshonly => true,
    require     => Service["drbd"],
  }

  # this file just includes other files
  file { "/etc/drbd.conf":
    ensure  => present,
    mode    => "0644",
    owner   => "root",
    content => '# file managed by puppet
include "/etc/drbd.conf.d/*.conf";
',
    require => Package["drbd"],
    before  => Service["drbd"],
    notify  => Exec["reload drbd"],
  }

  # only allow files managed by puppet in this directory.
  file { "/etc/drbd.conf.d/":
    ensure  => directory,
    source  => "puppet:///drbd/drbd.conf.d/",
    purge   => true,
    recurse => true,
    force   => true,
    require => Package["drbd"],
    notify  => Exec["reload drbd"],
  }

}
