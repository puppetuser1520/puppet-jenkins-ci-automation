# control-repo/site-modules/profile/manifests/jenkins.pp

class profile::jenkins (

  # --- REQUIRED behavior ---
  Integer $http_port = 8000,

  # --- Optional firewall management ---
  Boolean $manage_ufw = false,

  # --- Packages ---
  Array[String] $prereq_packages = ['ca-certificates','wget','fontconfig','gnupg'],
  String $java_package           = 'openjdk-21-jre-headless',

  # --- APT key + repo (data driven) ---
  String $keyring_dir     = '/etc/apt/keyrings',
  String $repo_key_path   = '/etc/apt/keyrings/jenkins-keyring.asc',
  String $repo_key_url    = 'https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key',
  String $repo_base_url   = 'https://pkg.jenkins.io/debian-stable',
  String $repo_list_path  = '/etc/apt/sources.list.d/jenkins.list',

  # --- systemd override paths (data driven) ---
  String $systemd_dropin_dir    = '/etc/systemd/system/jenkins.service.d',
  String $systemd_override_path = '/etc/systemd/system/jenkins.service.d/override.conf',

  # --- Optional listen address ---
  String $listen_address = '0.0.0.0',
) {

  # ---------------------------------------------------------------------------
  # Guardrails (explicit assumptions for the challenge)
  # ---------------------------------------------------------------------------
  if $facts['os']['name'] != 'Ubuntu' {
    fail("profile::jenkins: Ubuntu only (detected ${facts['os']['name']}).")
  }

  if $facts['os']['distro']['codename'] != 'jammy' {
    fail("profile::jenkins: Ubuntu 22.04 (jammy) only (detected ${facts['os']['distro']['codename']}).")
  }

  # ---------------------------------------------------------------------------
  # Prerequisites and Java
  # ---------------------------------------------------------------------------
  package { $prereq_packages:
    ensure => installed,
  }

  package { $java_package:
    ensure => installed,
  }

  # ---------------------------------------------------------------------------
  # APT keyrings directory
  # ---------------------------------------------------------------------------
  file { $keyring_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # ---------------------------------------------------------------------------
  # Download Jenkins signing key (idempotent)
  # Uses Jenkins 2026 key URL [2](https://stackoverflow.com/questions/68199970/change-jenkins-port)
  # ---------------------------------------------------------------------------
  exec { 'jenkins_repo_key':
    command => "/usr/bin/wget -qO ${repo_key_path} ${repo_key_url}",
    creates => $repo_key_path,
    path    => ['/usr/bin','/bin'],
    require => [
      File[$keyring_dir],
      Package['wget'],
    ],
  }

  # ---------------------------------------------------------------------------
  # Jenkins repository file (signed-by)
  # ---------------------------------------------------------------------------
  file { $repo_list_path:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "deb [signed-by=${repo_key_path}] ${repo_base_url} binary/\n",
    require => Exec['jenkins_repo_key'],
    notify  => Exec['apt_update_jenkins'],
  }

  # ---------------------------------------------------------------------------
  # apt-get update only when repo file changes
  # ---------------------------------------------------------------------------
  exec { 'apt_update_jenkins':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
    path        => ['/usr/bin','/bin'],
    require     => File[$repo_list_path],
  }

  # ---------------------------------------------------------------------------
  # Install Jenkins
  # ---------------------------------------------------------------------------
  package { 'jenkins':
    ensure  => installed,
    require => [
      Package[$java_package],
      Exec['apt_update_jenkins'],
    ],
  }

  # ---------------------------------------------------------------------------
  # systemd drop-in override directory
  # Jenkins recommends overrides via drop-in files. [1](https://thelinuxcode.com/install-configure-jenkins-ubuntu/)
  # ---------------------------------------------------------------------------
  file { $systemd_dropin_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # ---------------------------------------------------------------------------
  # Write override.conf from template (data-driven port)
  # ---------------------------------------------------------------------------
  file { $systemd_override_path:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('profile/jenkins_override.conf.erb'),
    require => [
      Package['jenkins'],
      File[$systemd_dropin_dir],
    ],
    notify  => Exec['systemd_daemon_reload'],
  }

  # ---------------------------------------------------------------------------
  # Reload systemd only when override changes; restart Jenkins only then
  # ---------------------------------------------------------------------------
  exec { 'systemd_daemon_reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    path        => ['/usr/bin','/bin'],
    notify      => Service['jenkins'],
  }

  # ---------------------------------------------------------------------------
  # Ensure Jenkins enabled and running
  # ---------------------------------------------------------------------------
  service { 'jenkins':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package['jenkins'],
      File[$systemd_override_path],
    ],
  }

  # ---------------------------------------------------------------------------
  # OPTIONAL: UFW (ensure running + allow port) - idempotent
  # ---------------------------------------------------------------------------
  if $manage_ufw {

    package { 'ufw':
      ensure => installed,
    }

    service { 'ufw':
      ensure  => running,
      enable  => true,
      require => Package['ufw'],
    }

    exec { 'ufw_allow_jenkins_port':
      command => "/usr/sbin/ufw allow ${http_port}/tcp",
      unless  => "/usr/sbin/ufw status | /bin/grep -Eq '\\b${http_port}/tcp\\b|\\b${http_port}\\b.*ALLOW'",
      path    => ['/usr/sbin','/usr/bin','/sbin','/bin'],
      require => Service['ufw'],
    }

    exec { 'ufw_must_be_active':
      command => '/bin/true',
      unless  => "/usr/sbin/ufw status | /bin/grep -q 'Status: active'",
      path    => ['/usr/sbin','/usr/bin','/sbin','/bin'],
      require => Service['ufw'],
    }
  }
}
