{# Counter‑Strike 2 dedicated server Salt state
   Assumptions:
     * Fedora 41 x86‑64 minimal install
     * Pillar key `cs2:gsl_token` contains the Game‑Server Login Token (GSLT)
     * Desired install dir: /home/steam/cs2-ds
#}

{% set gsl_token = salt['pillar.get']('cs2:gsl_token', '') %}

# ---------------------------------------------------------------------------
# 0. Ensure firewalld package & service (Fedora usually has it, but be explicit)
# ---------------------------------------------------------------------------
firewalld-package:
  pkg.installed:
    - name: firewalld

firewalld-service:
  service.running:
    - name: firewalld
    - enable: True
    - require:
        - pkg: firewalld-package

cs2-firewall-ports:
  firewalld.present:
    - name: cs2-ports
    - default: True
    - ports:
        - 27015/udp
        - 27015/tcp
    - services:
        - dhcpv6-client
        - mdns
        - ssh
        - cockpit
    - require:
        - service: firewalld-service

# ---------------------------------------------------------------------------
# 1. System packages & build tools
# ---------------------------------------------------------------------------

cs2-build-tools:
  cmd.run:
    - name: sudo dnf -y group install 'development-tools'

cs2-libraries:
  pkg.installed:
    - pkgs:
        - glibc.i686
        - libstdc++.i686
        - libcurl
        - tar
        - curl
        - gzip
        - cronie
        - policycoreutils-python-utils
        - httpd
        - mod_wsgi
        - python3-devel
        - python3-pip
        - python3-virtualenv
        - glances
        - tree
        - screen
        - git

# ---------------------------------------------------------------------------
# 2. steam user account
# ---------------------------------------------------------------------------
steam-user:
  user.present:
    - name: steam
    - shell: /bin/bash
    - home: /home/steam
    - createhome: True

# ---------------------------------------------------------------------------
# 3. SteamCMD installation
# ---------------------------------------------------------------------------
/opt/steamcmd:
  file.directory:
    - user: steam
    - group: steam
    - mode: 0755

steamcmd-tarball:
  file.managed:
    - name: /opt/steamcmd/steamcmd_linux.tar.gz
    - source: https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    - source_hash: sha256=cebf0046bfd08cf45da6bc094ae47aa39ebf4155e5ede41373b579b8f1071e7c
    - user: steam
    - group: steam
    - mode: 0644

steamcmd-extracted:
  cmd.run:
    - name: |
        tar -xzf steamcmd_linux.tar.gz --owner=steam --group=steam
    - cwd: /opt/steamcmd
    - runas: steam
    - creates: /opt/steamcmd/steamcmd.sh
    - require:
        - file: steamcmd-tarball

# ---------------------------------------------------------------------------
# 4. Install / update CS2 dedicated server
# ---------------------------------------------------------------------------
/home/steam/cs2-ds:
  file.directory:
    - user: steam
    - group: steam
    - mode: 0755

cs2-server-install:
  cmd.run:
    - name: |
        /opt/steamcmd/steamcmd.sh +login anonymous \
          +force_install_dir /home/steam/cs2-ds \
          +app_update 730 validate \
          +quit
    - runas: steam
    - env:
        - HOME: /home/steam
    - require:
        - cmd: steamcmd-extracted
        - file: /home/steam/cs2-ds
    - unless: test -x /home/steam/cs2-ds/game/bin/linuxsteamrt64/cs2

# ---------------------------------------------------------------------------
# Ensure Steamworks SDK library is discoverable
# ---------------------------------------------------------------------------
steam-sdk-dir:
  file.directory:
    - name: /home/steam/.steam/sdk64
    - user: steam
    - group: steam
    - makedirs: True
    - mode: 0755
    - require:
        - user: steam-user

steamclient-symlink:
  file.symlink:
    - name: /home/steam/.steam/sdk64/steamclient.so
    - target: /opt/steamcmd/linux64/steamclient.so
    - user: steam
    - group: steam
    - require:
        - file: steam-sdk-dir
        - cmd: steamcmd-extracted

# ---------------------------------------------------------------------------
# Update Cron
# ---------------------------------------------------------------------------
cs2-update-cron:
  cron.present:
    - name: "/opt/steamcmd/steamcmd.sh +login anonymous +force_install_dir /home/steam/cs2-ds +app_update 730 +quit"
    - user: steam
    - hour: 4
    - minute: 30
    - require:
        - cmd: cs2-server-install