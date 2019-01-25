# Jenkins Agent Profile
#
# Profile class for a node configured to act as a swarm agent for Jenkins.
# This profile should only ever be declared with an include into a role or site manifest.
# Parameter overloading should be done using hiera automatic parameter lookup.
#
# @example
#    include profile::jenkins::master
#
# @pararm agent_username The unix user the agent will configure and run as.
class profile::jenkins::agent_gpu {

  include apt

  package { 'nvidia-375':
    ensure => installed,
  }

  package { 'wget':
    ensure => installed,
  }

  exec { 'apt-update':
    command => "/usr/bin/apt-get update"
  }

  exec { 'retrieve_docker_repo':
    command => '/usr/bin/wget -q https://nvidia.github.io/nvidia-docker/ubuntu16.04/nvidia-docker.list -O /etc/apt/sources.list.d/nvidia-docker.list',
    creates => '/etc/apt/sources.list.d/nvidia-docker.list',
    require => Package['wget'],
  }

  apt::key { 'nvidia_docker_key' :
    source => 'https://nvidia.github.io/nvidia-docker/gpgkey',
    id     => 'C95B321B61E88C1809C4F759DDCAE044F796ECB0',
  }

  package { 'nvidia-docker2':
    ensure  => installed,
    require => [
      Exec['retrieve_docker_repo'],
      Apt::Key['nvidia_docker_key'],
      Exec['apt-update']
    ],
  }

  package { 'lightdm':
    ensure => installed,
  }

  file { '/etc/lightdm/xhost.sh':
    source  => 'puppet:///modules/agent_files/etc/lightdm/xhost.sh',
    mode    => '0744',
    require => Package[lightdm],
    notify  => Exec[service_lightdm_restart],
  }

  # This two rules do: check if no lightdm is present and create one
  # Ensure that display-setup-script is set

  file { '/etc/lightdm/lightdm.conf':
    ensure  => 'present',
    source  => 'puppet:///modules/agent_files/etc/lightdm/lightdm.conf',
    replace => 'no', # this is the important property
    require => File['/etc/lightdm/xhost.sh']
  }

  file_line { '/etc/lightdm/lightdm.conf':
    ensure  => present,
    require => File['/etc/lightdm/lightdm.conf'],
    line    => 'display-setup-script=/etc/lightdm/xhost.sh',
    path    => '/etc/lightdm/lightdm.conf',
  }

  service { 'lightdm':
    ensure     => running,
    enable     => true,
    hasrestart => true,
  }

  exec { 'service_lightdm_restart':
    refreshonly => true,
    command     => '/usr/sbin/service lightdm restart',
    require     => [ Package['lightdm'], File['/etc/lightdm/lightdm.conf'] ]
  }
}
