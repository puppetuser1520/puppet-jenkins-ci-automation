
***

# Jenkins CI Automation with Puppet (Ubuntu 22.04)

## 1. Introduction

This project provides a **fully automated, idempotent Puppet solution** to install and configure the **Jenkins Continuous Integration server** on **Ubuntu 22.04 (Jammy Jellyfish)**.

The automation follows **Puppet best practices**:

*   **Roles & Profiles** pattern for separation of concerns
*   **Data‑driven configuration** using Hiera
*   **No external Puppet Forge modules** (only core Puppet resources)
*   **Idempotent execution** so repeated runs are safe
*   **Upgrade‑safe Jenkins configuration** using systemd drop‑in overrides

Jenkins is explicitly configured to **listen on port 8000**, satisfying the requirement that Jenkins itself—not port forwarding—serves traffic on that port.

***

## 2. Prerequisites (Environment)

### Supported Operating System

*   **Ubuntu 22.04 LTS (Jammy Jellyfish)**
    *   This solution intentionally fails fast on unsupported operating systems.

### Required Software

*   **Puppet Agent** (Open Source)
*   **systemd** (default init system on Ubuntu 22.04)
*   **Internet access** to download Jenkins packages and dependencies

### Assumptions

*   The system starts as a **clean OS installation**
*   The user has **root or sudo privileges**
*   No Jenkins installation exists prior to applying this solution

***

## 3. Puppet Installation Steps (Ubuntu 22.04)

```bash
# Update package index
sudo apt update

# Install Puppet Agent
sudo apt install -y puppet

# Verify installation
puppet --version
```

Once Puppet is installed, no additional Ruby libraries, Forge modules, or plugins are required.

***

## 4. Project Structure

```text
control-repo/
├── environment.conf
├── hiera.yaml
├── manifests/
│   └── site.pp
├── data/
│   ├── common.yaml
│   └── env/
│       └── production.yaml
└── site-modules/
    ├── role/
    │   └── manifests/
    │       └── jenkins_controller.pp
    └── profile/
        ├── manifests/
        │   └── jenkins.pp
        └── templates/
            └── jenkins_override.conf.erb
```

### Structure rationale

*   **Role** describes *what* the node is: `jenkins_controller`
*   **Profile** describes *how* Jenkins is installed/configured
*   **Hiera data** controls all environment‑specific values (port, packages, paths)

***

## 5. Project Automation Flow (Conceptual Diagram)

```text
           +-------------------------+
           |     Puppet Apply        |
           +-------------------------+
                       |
                       v
           +-------------------------+
           |  role::jenkins_controller |
           +-------------------------+
                       |
                       v
           +-------------------------+
           |     profile::jenkins    |
           +-------------------------+
                       |
   +-----------+-----------+-----------+
   |           |           |           |
   v           v           v           v
 OS Checks   Packages    Jenkins Repo  systemd Override
                                   |
                                   v
                            Jenkins on Port 8000
```

***

## 6. Project Execution Explanation

1.  **Classification**
    *   The node is assigned `role::jenkins_controller` from `site.pp`.

2.  **Profile execution**
    *   `profile::jenkins` installs prerequisites and Java.
    *   Jenkins APT repository and signing key are configured.
    *   Jenkins package is installed.
    *   A **systemd drop‑in override** file is created to set `JENKINS_PORT=8000`.

3.  **Idempotency**
    *   `exec` resources are guarded with `creates`, `unless`, or `refreshonly`.
    *   `systemctl daemon-reload` and Jenkins restarts occur **only when configs change**.
    *   Re‑running Puppet produces **no redundant actions**.

***

## 7. Most Difficult Hurdle (with Official References)

### Hurdle: Configuring Jenkins to listen on port 8000 in an upgrade‑safe way

The main technical challenge was ensuring that **Jenkins itself** listens on port 8000 **without modifying package‑managed files**.

Modern Jenkins Debian/Ubuntu packages:

*   Are managed by **systemd**
*   Explicitly discourage editing `/lib/systemd/system/jenkins.service`
*   Require **drop‑in override files** under  
    `/etc/systemd/system/jenkins.service.d/override.conf`

This approach ensures:

*   Configuration persists across Jenkins upgrades
*   Puppet remains idempotent
*   The system adheres to Jenkins’ supported configuration model

### Official reference

*   Jenkins systemd service management documentation:  
    <https://www.jenkins.io/doc/book/system-administration/systemd-services/> [\[jenkins.io\]](https://www.jenkins.io/doc/book/system-administration/systemd-services/)

### Additional hurdle: Jenkins repository key rotation

Jenkins rotated its Linux repository signing key in late 2025.  
Failing to use the **2026 key** causes clean Ubuntu installs to fail package validation.

Official notice:  
<https://www.jenkins.io/blog/2025/12/23/repository-signing-keys-changing/> [\[jenkins.io\]](https://www.jenkins.io/blog/2025/12/23/repository-signing-keys-changing/)

***

## 8. Required Question Answers

### a) Most difficult hurdle

The hardest part was configuring Jenkins to listen on port 8000 **without editing package‑managed files**, while remaining **upgrade‑safe and idempotent**.  
Using systemd drop‑in overrides was essential and mandated careful ordering (`notify` / `refreshonly`) so Jenkins restarts only when configuration changes.

***

### b) Why requirement (f) is important

Requirement (f) enforces **idempotency**, which is fundamental to configuration management.  
Without idempotency:

*   Automation becomes unsafe
*   Re-runs may cause repeated restarts or failures
*   Configuration drift increases

Puppet’s ability to apply the same manifests repeatedly while maintaining the desired state—without unnecessary changes—is what makes it suitable for long‑lived infrastructure.

Official Puppet documentation on idempotency:  
<https://help.puppet.com/pe/current/topics/understanding_idempotency.html> [\[help.puppet.com\]](https://help.puppet.com/pe/current/topics/understanding_idempotency.htm)

***

### c) Sources of information

Primary sources used:

*   **Jenkins official documentation**
    *   systemd service overrides  
        <https://www.jenkins.io/doc/book/system-administration/systemd-services/> [\[jenkins.io\]](https://www.jenkins.io/doc/book/system-administration/systemd-services/)
    *   repository key rotation blog  
        <https://www.jenkins.io/blog/2025/12/23/repository-signing-keys-changing/> [\[jenkins.io\]](https://www.jenkins.io/blog/2025/12/23/repository-signing-keys-changing/)
*   **Puppet official documentation**
    *   Idempotency concepts  
        <https://help.puppet.com/pe/current/topics/understanding_idempotency.html> [\[help.puppet.com\]](https://help.puppet.com/pe/current/topics/understanding_idempotency.htm)

No third‑party Puppet modules or copied community code were used.

***

### d) What automation means and why it matters

Automation means defining infrastructure and system configuration as **code that expresses intent**, not imperative steps.  
It enables:

*   Consistency across environments
*   Reduced human error
*   Safe reconfiguration at scale
*   Faster recovery from failure

In an organization’s infrastructure strategy, automation allows systems to be **reliably rebuilt, updated, and audited**, forming the foundation of scalable, secure CI/CD and cloud‑native operations.

***
