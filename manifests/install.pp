# = Class: jboss::install
#
# Sets up the system for installing JBoss AS.
# It is intended to be called by jboss::jboss.
#
# == Actions:
#
# * Creates JBoss user and group;
# * makes <tt>/opt</tt> folder group owned by jboss and group writable;
# * creates /home/jboss/bin folder to host some management scripts;
# * according to the parameter <tt>jboss_instance_list</tt> creates in /usr/local/bin a text file with all
# the instance names on the node, one per line.
class jboss::install (Boolean $jboss_instance_list = false){
  user { 'jboss':
    ensure     => present,
    comment    => 'JBoss user',
    gid        => 'jboss',
    shell      => '/bin/bash',
    managehome => true,
  }

  group { 'jboss':
    ensure => present,
  }

  file { '/opt':
    ensure => present,
    group  => jboss,
    mode   => 'g+w',
  }

  file { '/home/jboss/bin':
    ensure  => directory,
    require => User['jboss'],
  }

  if $jboss_instance_list {
    Concat::Fragment <<| target == '/usr/local/bin/jboss-instance-list.conf' and
    tag == $::fqdn |>> {
    }

    concat { '/usr/local/bin/jboss-instance-list.conf':
      ensure => present,
    }
  }
}