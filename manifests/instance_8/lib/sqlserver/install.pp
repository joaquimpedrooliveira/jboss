# = Define: jboss::instance_8::lib::sqlserver::install
#
# Utility define to copy to a specified WildFly-8.2.0 instance the sqlserver
# driver jar module.
#
# == Parameters:
#
# $instance_name::  Name of the JBoss profile and associated service
#                   corresponding to this instance.
#                   Defaults to the resource title.
#
# $environment::    Abbreviation identifying the environment: valid values are
# +dev+, +test+, +prep+, +prod+.
#                   Defaults to +dev+.
#
# == Actions:
#
# Creates the sqlserver module into the specified instance.
#
# == Requires:
#
# * Class['jboss'] for installing and setting up basic jboss environment.
# * Some defined instance to which the driver has to be copied.
# * The specified instance has to be up and running.
#
# == Sample usage:
#
#  jboss::instance_8::lib::sqlserver::install {'agri1':
#  }
define jboss::instance_8::lib::sqlserver::install (
  $instance_name = $title,
  $environment   = 'dev') {
  $require = Class['jboss']

  $ip_alias = "${instance_name}-${environment}"
  $jbossVersion = 'wildfly-8.2.0.Final'
  $jbossInstFolder = "/opt/jboss-8-${instance_name}/${jbossVersion}"
  $binFolder = "${jbossInstFolder}/bin"
  $modulesFolder = "${jbossInstFolder}/modules/system/layers/base"
  $sqlserverModulePath = "${modulesFolder}/com/microsoft/sqljdbc4/main"

  File {
    owner => jboss,
    group => jboss,
  }

  Exec {
    user  => jboss,
    group => jboss,
  }

  exec { "create_sqlserver_module_folders_${instance_name}":
    command => "mkdir -p ${sqlserverModulePath}",
    creates => $sqlserverModulePath,
  } ->
  file { "${sqlserverModulePath}/module.xml":
    source => "puppet:///modules/${module_name}/lib/sqlserver/module.xml",
  } ->
  download_uncompress { "${sqlserverModulePath}/sqljdbc4.jar":
    distribution_name => 'lib/sqljdbc4.jar',
    dest_folder       => $sqlserverModulePath,
    creates           => "${sqlserverModulePath}/sqljdbc4.jar",
    user              => jboss,
    group             => jboss,
  } ->
  # Configurazione driver
  file { "${binFolder}/script-driver-sqlserver.txt":
    ensure => present,
    source => "puppet:///modules/${module_name}/bin/script-driver-sqlserver.txt",
  } ->
  exec { "configure_driver_sqlserver_${instance_name}":
    command => "${binFolder}/myjboss-cli.sh --controller=${ip_alias} --file=script-driver-sqlserver.txt",
    cwd     => $binFolder,
    unless  => "grep com.microsoft.sqljdbc4 ${jbossInstFolder}/standalone/configuration/standalone.xml",
  }

}
