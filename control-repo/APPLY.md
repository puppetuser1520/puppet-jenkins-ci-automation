# Applying the Puppet solution (Ubuntu 22.04 only)

## Assumptions
- Runs ONLY on Ubuntu 22.04 (jammy).
- Target machine has internet access to Jenkins APT repository.
- Puppet Agent is installed and you run puppet as root (sudo).
- systemd is the init system (default on Ubuntu 22.04).
- Fresh OS install is recommended.

## Steps (puppet apply)
1) Copy `control-repo/` to:
   `/etc/puppetlabs/code/environments/production/`

2) Run:
```bash
sudo puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp \
  --environment production \
  --hiera_config /etc/puppetlabs/code/environments/production/hiera.yaml \
  --modulepath /etc/puppetlabs/code/environments/production/site-modules