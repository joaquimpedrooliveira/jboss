sudo #jboss

####Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with jboss](#setup)
    * [What jboss affects](#what-jboss-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with jboss](#beginning-with-jboss)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

##Overview

This is the jboss module. It provides classes and defines to install, configure, and create services for jboss instances for the versions 4, 5, 7 of JBoss-GA and WildFly-8.

##Module Description

Creates, configures and sets up the service, i.e. a server profile with all the configurations needed to use it as an independent service, for JBoss instances for the community versions:

* JBoss-4.x.y.GA
* JBoss-5.1.0.GA
* JBoss-7.1.1.Final
* WildFly-8.2.0.Final

*Note*: at this time the 7 and 8 instances are created as standalone standard profiles.

The module takes care to set up a secondary network interface on which the instance will be listening.

The module incorporates sensible defaults so the only required parameter is the resource title that will be used as instance name.

##Setup

###What jboss affects

The module impact in various ways on the node:

* JBoss distribution and profiles are installed in `/opt` folder;
* logs go in `/var/jboss/server/[instance_name]` folder;
* applications specific files go in `/var/lib/jboss/apps/[appname]` folder;
* a service is created in `/etc/init.d` with the name `jboss-[instance_name]` and configured to start at boot;
* users belonging to jboss group gain specific sudoers permissions in order to start and stop jboss services, to su to jboss user, to use basic network debug tools like netstat and nmap, and to enable/disable/launch a single run of puppet agent;
* if an IP address is specified to make the instance listening then a secondary network interface with the specified IP is configured and activated;
* an alias for the specified IP is created in the /etc/hosts file as [instance_name]-[environment];
* a script to zip and delete old logs in `/var/jboss/server/[instance_name]` folder is installed in `/home/jboss/bin` and scheduled as a cron job of the jboss user;
* a script to ease the management of JBoss services is installed in `/usr/local/bin`;
* JBoss-4 and JBoss-5 instances will include the installation of Java-6 while Jboss-7 and WildFly-8 instances will include the installation of Java-7.
* if WildFly-8 instances are installed on a node then a symbolic link `/opt/jboss-8` is created to one of them in order to have the possibility to access the scripts in the WildFly `bin` directory on a standard path (e.g. to access jboss-cli.sh in postconfig manifests).

If PuppetDB is installed the module exports two kind of resources:

* the hostname aliases [instancename]-[environment] corresponding to the instances created;
* the paths to backup the configurations of the specific instances created on a given node in a given environment. (The node fqdn and the environment tag concat::fragment resources).

The module provides a class `jboss::alias_jboss` that use the first above mentioned exported resource to define a utility class to add all jboss instances hostnames in the hosts file of a node.

For JBoss instances 5, 7, and 8 JBoss logs will be configured with a special category 'LoggerPrestazioni' that appends to a DailyRollingFileAppender named `prestazioni.log`. We use such category to log timings of the different servlets, in order to evaluate overall performances of the webapps.

In order to prevent Puppet to alter specific instance configuration files the general rule followed is to create required JBoss-instance specific configurations (like the above affecting logs) only when they are absent and leaving the files untouched if the configurations already exist.

###Setup Requirements

This modules requires the following other modules to be installed:

* dsestero/download_uncompress

    to provide the basic capability to download and unzip the JBoss distributions
    
* dsestero/java

    to install a suitable java development environment
    
* puppetlabs/concat

    to create the lines needed to configure backup 

* puppetlabs/concat

    to collect informations about the instances installed on a node.

* puppetlabs/stdlib

    to use various functions and the `file_line` resource.

To make use of the exported resources mentioned in [reference](#reference) PuppetDB has to be installed.
	
###Beginning with jboss	

To get a jboss instance up and running one has to install a specific version of the JBoss Community distribution and then to declare the specific instance. This is done, for example, by declarations as the following:

```
include jboss::jboss_8
jboss::instance_8 { 'instanceName': }
```

In the above example a WildFly-8 standalone instance is configured to listen on localhost (127.0.0.1) as a development (`dev`) environment without creating management or jmx users.

##Usage

The basic usage is as in the following example:

```
include jboss::jboss_8
jboss::instance_8 { 'instanceName':
    environment => 'prod',
    ip          => '172.16.13.15',
    iface       => 'eth0:8',
    mgmt_user   => $mgmt_user,
    mgmt_passwd => $mgmt_passwd,
}
```

If `ip` is provided but no `iface` then the instance will listen on the specified `ip` but no specific secondary interface will be created.

It is possible to specify additional attributes like the Xms and Xmx (start and maximum heap memory used by the instance) or the smtp configurations for the JBoss mail service:

```
  jboss::instance_5 { 'agri1':
    profile     => 'web',
    ws_enabled  => true,
    environment => 'prod',
    ip          => '172.16.12.165',
    iface       => 'eth0:1',
    jmxport     => '12345',
    xmx         => '1024m',
    mgmt_user   => 'admin',
    mgmt_passwd => 'jboss@2009',
    jmx_user    => 'zabbixinva',
    jmx_passwd  => 'z3n055__',
    smtp_ip     => '172.16.10.76',
    smtp_domain => 'regione.vda.it',
  } ->
  jboss::instance_5::lib::oracle::install { 'agri1':
  } ->
  jboss::instance_5::lib::zk::install { 'agri1':
  }
```

It is possible to concatenate the declarations for specific libraries as in, for example:

```
  jboss::instance_8 { 'transito8':
    environment => 'test',
    mgmt_user   => 'mgmt_user',
    mgmt_passwd => 'mgmt_passwd',
  } ->
  jboss::instance_8::lib::oracle::install { 'transito8':
    environment => 'test',
  } ->
  jboss::instance_8::lib::postgresql::install { 'transito8':
    environment => 'test',
  } ->
  jboss::instance_8::lib::springframework::install { 'transito8':
    environment => 'test',
  }
```

###Exported resources

The exported paths to backup for a given node can be collected, for instance to configure a backup, script with a declaration like the following:

```
  Concat::Fragment <<| target == '/usr/local/bin/backupall.sh.conf' and tag == $::fqdn |>> {
  }

  concat { '/usr/local/bin/backupall.sh.conf':
    ensure => present,
  }
```

The names of all instances defined on a node, one per line, are exported and the following code, that is actually part of class jboss::install can be used in case one needs such a file:

```
  Concat::Fragment <<| target == '/usr/local/bin/jboss-instance-list.conf' and tag == $::fqdn |>> {
  }

  concat { '/usr/local/bin/jboss-instance-list.conf':
    ensure => present,
  }

``` 

Furthermore, the module provides a class `jboss::alias_jboss` that uses the exported hostname alias to define a utility class that can be exploited to add all jboss instances hostnames in the hosts file of a node.

##Reference

###Classes

####Public Classes
* [`jboss::alias_jboss`](#jbossalias_jboss): Adds all jboss instances ip and alias in the hosts file.
* [`jboss::jboss`](#jbossjboss): Installs and set up standard directories and permissions for JBoss AS.
* [`jboss::jboss_4_0_5`](#jbossjboss_4_0_5): Installs JBoss-4.0.5.GA.
* [`jboss::jboss_4_2_3`](#jbossjboss_4_2_3): Installs JBoss-4.2.3.GA.
* [`jboss::jboss_5`](#jbossjboss_5): Installs JBoss-5.
* [`jboss::jboss_7`](#jbossjboss_7): Performs basic jboss configuration in order to install JBoss-7 instances.
* [`jboss::jboss_8`](#jbossjboss_8): Performs basic jboss configuration in order to install WildFly-8 instances.

####Private Classes
* [`jboss::params`](#jbossparams): Defines the parameters needed for installing JBoss/WildFly instances.
* [`jboss::install`](#jbossconfig): Sets up the system for installing JBoss/WildFly AS.
* [`jboss::config`](#jbossconfig): Configures JBoss/WildFly AS.

###Defines

####Public Defines
* [`jboss::jboss_4`](#jbossjboss_4): Installs JBoss-4.
* [`jboss::instance_4`](#jbossinstance_4): Creates, configures and set up the service for a JBoss-4-family instance, i.e. a server profile with all the configurations needed to use it as an independent service.
* [`jboss::instance_5`](#jbossinstance_5): Creates, configures and set up the service for a JBoss-5.1.0.GA instance, i.e. a server profile with all the configurations needed to use it as an independent service.
* [`jboss::instance_7`](#jbossinstance_7): Creates, configures and set up the service for a JBoss-7.1.1.Final instance, i.e. a server profile with all the configurations needed to use it as an independent service.
* [`jboss::instance_8`](#jbossinstance_8): Creates, configures and set up the service for a WildFly-8.2.0.Final instance, i.e. a server profile with all the configurations needed to use it as an independent service.
* [`jboss::instance_5::lib::oracle::install`](#jbossinstance_5liboracleinstall): Copies to a specified JBoss-5 instance lib folder the Oracle driver jar.
* [`jboss::instance_5::lib::sqlserver::install`](#jbossinstance_5libsqlserverinstall): Copies to a specified JBoss-5 instance lib folder the SQLServer driver jar.
* [`jboss::instance_5::lib::zk::install`](#jbossinstance_5libzkinstall): Copies to a specified JBoss-5 instance lib folder the zk library jars.
* [`jboss::instance_5::persistence::install`](#jbossinstance_5persistenceinstall): Adds to a specified instance the Oracle persistence service
* [`jboss::instance_7::lib::oracle::install`](#jbossinstance_7liboracleinstall): Copies to a specified JBoss-7 instance module folder the Oracle driver jar and configures it.
* [`jboss::instance_7::lib::postgresql::install`](#jbossinstance_7libpostgresqlinstall): Copies to a specified JBoss-7 instance module folder the PostgreSQL driver jar and configures it.
* [`jboss::instance_7::lib::sqlserver::install`](#jbossinstance_7libsqlserverinstall): Copies to a specified JBoss-7 instance module folder the SQLServer driver jar and configures it.
* [`jboss::instance_7::lib::springframework::install`](#jbossinstance_7libspringframeworkinstall): Copies to a specified JBoss-7 instance lib folder the Spring Framework library jars.
* [`jboss::instance_8::lib::oracle::install`](#jbossinstance_8liboracleinstall): Copies to a specified WildFly-8 instance module folder the Oracle driver jar and configures it.
* [`jboss::instance_8::lib::postgresql::install`](#jbossinstance_8libpostgresqlinstall): Copies to a specified WildFly-8 instance module folder the PostgreSQL driver jar and configures it.
* [`jboss::instance_8::lib::sqlserver::install`](#jbossinstance_8libsqlserverinstall): Copies to a specified WildFly-8 instance module folder the SQLServer driver jar and configures it.

####Private Defines
* [`jboss::instance::config`](#jbossinstanceconfig): Configures a JBoss/WildFly instance.
* [`jboss::instance::install`](#jbossinstanceinstall): Installs a JBoss/WildFly instance.
* [`jboss::instance::service`](#jbossinstanceservice): Sets up a service for a JBoss/WildFly instance.
* [`jboss::instance_4::config`](#jbossinstance_4config): Configures a JBoss-4-family instance.
* [`jboss::instance_4::install`](#jbossinstance_4install): Installs a JBoss-4-family instance.
* [`jboss::instance_5::config`](#jbossinstance_5config): Configures a JBoss-5.1.0.GA instance.
* [`jboss::instance_5::install`](#jbossinstance_5install): Installs a JBoss-5.1.0.GA instance.
* [`jboss::instance_7::config`](#jbossinstance_7config): Configures a JBoss-7.1.1.GA instance.
* [`jboss::instance_7::install`](#jbossinstance_7install): Installs a JBoss-7.1.1.GA instance.
* [`jboss::instance_7::postconfig`](#jbossinstance_7postconfig): Postconfigures a JBoss-7.1.1.GA instance.
* [`jboss::instance_8::config`](#jbossinstance_8config): Configures a WildFly-8.2.0.Final instance.
* [`jboss::instance_8::install`](#jbossinstance_8install): Installs a WildFly-8.2.0.Final instance.
* [`jboss::instance_8::postconfig`](#jbossinstance_8postconfig): Postconfigures a WildFly-8.2.0.Final instance.

###`jboss::alias_jboss`
Defines a utility class to add all jboss instances ip and alias in the hosts file.

###`jboss::jboss`
Installs and set up standard directories and permissions for JBoss AS. Specifically:

* creates jboss user and group;
* makes `/opt` folder group owned by jboss and group writable.
* sets the JBoss directories with correct ownership
* creates /home/jboss/bin folder to host some management scripts;
* creates in /home/jboss/bin a text file with all the instance names on the node, one per line
* modify `/etc/sudoers` file so to allow jboss user the right to start and stop jboss instances and soffice.bin services, make `su jboss`, and to query open ports with `netstat` and `nmap`;
* deploys in the jboss user bin directory a script for for zipping and deleting old log files belonging to the JBoss instances and schedule a jboss user's cron job for it;
* deploys in the `/usr/local/bin` directory a script for restarting jboss instances;
* creates standard directories for logging and storing application's specific data under
  `/var/log/jboss/server` and `/var/lib/jboss/apps` respectively.

###`jboss::jboss_4_0_5`
Installs JBoss-4.0.5.GA.

###`jboss::jboss_4_2_3`
Installs JBoss-4.2.3.GA.

###`jboss::jboss_4`
Installs JBoss-4. The resource title has to be an unique name identifying the JBoss installation and it could be used to specify
the desired version. Specifically:

* Downloads the distribution from SourceForge and
* Unzip the distribution under <tt>/opt</tt>.

Supported versions are: <tt>4.0.0</tt>, <tt>4.0.2</tt>, <tt>4.0.4</tt>, <tt>4.0.5</tt>, <tt>4.2.0</tt>, <tt>4.2.1</tt>, <tt>4.2.2</tt>, <tt>4.2.3</tt>.

Note that the download of the distribution takes place only if the distribution is not present in <tt>/tmp</tt> and the
distribution was not yet unzipped.

####Parameters

#####`version`
JBoss version. It has to be a three number string denoting a specific version in the JBoss-4 family.
Defaults to the resource title.

#####`jdksuffix`
The string indicating the possible suffix of the filename to specify the jdk used to compile the distribution.
Defaults to ''.

###`jboss::jboss_5`
Installs JBoss-5.1.0.GA. 

* Unzip the distribution under <tt>/opt</tt>; 
* includes [jboss](#jboss::jboss) class;
* creates a link <tt>/opt/jboss</tt> pointing to the JBoss-5.1.0.GA installation folder;
* furthermore, copies a zip of the files needed to deploy jbossws web service under <tt>/opt</tt> and unzip it.

###`jboss::jboss_7`
At the moment this class simply calls `jboss::jboss` to perform basic jboss configurations.

###`jboss::jboss_8`
At the moment this class simply calls `jboss::jboss` to perform basic jboss configurations.

###`jboss::instance_4`
Creates, configures and set up the service for a JBoss-4-family instance, i.e. a server profile with all the configurations needed to use it as an independent service.

###`jboss::instance_5`
Creates, configures and set up the service for a JBoss-5.1.0.GA instance, i.e. a server profile with all the configurations needed to use it as an independent service.

###`jboss::instance_7`
Creates, configures and set up the service for a JBoss-7.1.1.Final instance, i.e. a server profile with all the configurations needed to use it as an independent service. 

*Note*: at this time the instance is created as a standalone standard profile.

###`jboss::instance_8`
Creates, configures and set up the service for a WildFly-8.2.0.Final instance, i.e. a server profile with all the configurations needed to use it as an independent service. 

*Note*: at this time the instance is created as a standalone standard profile.

####Parameters common to all types of instances

#####`backup_conf_target`

Full pathname of the backup configuration file where the instance paths to backup are added.
Defaults to `/usr/local/bin/backupall.sh.conf`.

#####`environment`

Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.
*Note:* hot code deployment is disabled in the environments `prep` and `prod`, enabled on `dev` and `test`.

#####`iface`

Name of the secondary network interface dedicated to this instance.
Defaults to `undef`, in which case a secondary network interface to bind the jboss instance is not created.

#####`instance_name`

Name of the JBoss profile and associated service corresponding to this instance.
Defaults to the resource title.

#####`ip`

Dedicated IP on which this instance will be listening.
Defaults to `127.0.0.1` i.e. localhost.

#####`max_perm_size`

JVM OPT for max permanent generations size.
Defaults to `256m`.

#####`mgmt_user`

Management user username.
Defaults to `undef`, in which case a management user is not created.

#####`mgmt_passwd`

Management user password.
Defaults to `undef`.

#####`stack_size`

JVM OPT for stack size.
Defaults to `2048k`.

#####`xms`

JVM OPT for initial heap size.
Defaults to `128m`.

#####`xmx`

JVM OPT for maximum heap size.
Defaults to `512m`.

####Parameters specific of `instance_4`

#####`profile`

Name of the standard JBoss profile from which this one is derived.
As of JBoss-5.1.0.GA different profiles are provided with a different level of services made available; they are:
`minimal`, `web`, `default`, `all`.
Defaults to `default`.

#####`jmx_user`

JMX user username.
Defaults to `undef`, in which case a management user is not created.

#####`jmx_passwd`

JMX user password.
Defaults to `undef`.

####Parameters specific of `instance_5`

#####`extra_jvm_pars`
extra JVM OPTS.
Defaults to ''.

#####`jmxport`
JMX port to use to monitor this instance.
Defaults to `no_port`, in which case no JMX monitoring is activated.

#####`profile`
Name of the standard JBoss profile from which this one is derived.
As of JBoss-5.1.0.GA different profiles are provided with a different level of services made available; they are:
`minimal`, `web`, `default`, `all`.
Defaults to `default`.

#####`smtp_domain`
What will appear as default sender domain of the emails sent by the JBoss mail service.
Defaults to `nosuchhost.nosuchdomain.com`.

#####`smtp_ip`
IP of the smtp server used by the JBoss mail service.
Defaults to `undef`, in which case the mail service is not configured.

#####`smtp_port`
Port of the smtp server used by the JBoss mail service.
Defaults to `25`.

#####`ws_enabled`

`true` if deploying a web profile that has to be enabled for jbossws.
Defaults to `false`.

#####`jmx_user`

JMX user username.
Defaults to `undef`, in which case a management user is not created.

#####`jmx_passwd`

JMX user password.
Defaults to `undef`.

####Parameters specific of `instance_7`

#####`distribution_name`

Name of the distribution bundle to download, used for installing customed distributions.
Defaults to `jboss-as-7.1.1.Final.zip`

#####`jbossdirname`

Name of the jboss installation folder.
Defaults, according to the JBoss major release, to `jboss-as-7.1.1.Final`

#####`jmx_user`

JMX user username.
Defaults to `undef`, in which case a management user is not created.

#####`jmx_passwd`

JMX user password.
Defaults to `undef`.

####Parameters specific of `instance_8`

#####`distribution_name`

Name of the distribution bundle to download, used for installing customed distributions.
Defaults to `wildfly-8.2.0.Final.tar.gz`

#####`jbossdirname`

Name of the jboss installation folder.
Defaults, according to the JBoss major release, to `wildfly-8.2.0.Final`

###`jboss::instance_5::lib::oracle::install`
Utility define to copy to a specified JBoss-5 instance lib folder the Oracle driver jar.

####Parameters

#####`instance_name`
Name of the JBoss profile and associated service corresponding to the instance where the driver has to be copied.
Defaults to the resource title.

###`jboss::instance_5::lib::sqlserver::install`
Utility define to copy to a specified JBoss-5 instance lib folder the SQL server driver jar.

####Parameters

#####`instance_name`
Name of the JBoss profile and associated service corresponding to the instance where the driver has to be copied.
Defaults to the resource title.

###`jboss::instance_5::lib::zk::install`
Utility define to copy to a specified JBoss-5 instance lib folder the zk jars.

####Parameters

#####`instance_name`
Name of the JBoss profile and associated service corresponding to the instance where the libraries have to be copied.
Defaults to the resource title.

###`jboss::instance_7::lib::oracle::install`
Utility define to copy to a specified JBoss-7 instance module folder the Oracle driver jar and
to configure the driver in the application server by executing a jboss-cli script.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the driver has to be copied and configured.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

###`jboss::instance_7::lib::postgresql::install`
Utility define to copy to a specified JBoss-7 instance module folder the PostgreSQL driver jar and
to configure the driver in the application server by executing a jboss-cli script.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the driver has to be copied and configured.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

###`jboss::instance_7::lib::sqlserver::install`
Utility define to copy to a specified JBoss-7 instance module folder the SQLServer driver jar and to configure the driver in the application server by executing a jboss-cli script.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the driver has to be copied and configured.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

###`jboss::instance_7::lib::springframework::install`
Utility define to copy to a specified JBoss-7 instance module folder the Spring Framework jars.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the libraries have to be copied.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

###`jboss::instance_8::lib::oracle::install`
Utility define to copy to a specified WildFly-8 instance module folder the Oracle driver jar and
to configure the driver in the application server by executing a jboss-cli script.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the driver has to be copied and configured.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

###`jboss::instance_8::lib::postgresql::install`
Utility define to copy to a specified WildFly-8 instance module folder the PostgreSQL driver jar and
to configure the driver in the application server by executing a jboss-cli script.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the driver has to be copied and configured.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

###`jboss::instance_8::lib::sqlserver::install`
Utility define to copy to a specified WildFly-8 instance module folder the SQLServer driver jar and to configure the driver in the application server by executing a jboss-cli script.

####Parameters

#####`instance_name`
Name of the JBoss standalone instance and associated service where the driver has to be copied and configured.
Defaults to the resource title.

#####`environment`
Abbreviation identifying the environment: valid values are `dev`, `test`, `prep`, `prod`.
Defaults to `dev`.

##Limitations

The module targets Debian and RedHat distributions, including Ubuntu and CentOS. Specifically, it is tested on Ubuntu 12.04 and CentOS 6.6 with 64 bit architecture, although probably it will work also on different versions and on 32 bit architecture.

Furthermore JBoss-7 and WildFly-8 instances are created in standalone mode.

Due to the fact that JBoss-7 and WildFly-8 instances need a `postconfig` phase implemented by calling the `jboss-cli.sh` script, it is necessary that the instance be up and running at that time. When Puppet just creates the instance in most cases it is not yet ready to accept connections from jboss-cli because the services are still starting. That's no problem because Puppet will complete the configuration (specified in the postconfig phase) at the subsequent run.

##Development

If you need some feature please send me a (pull) request or send me an email at: dsestero 'at' gmail 'dot' com.

