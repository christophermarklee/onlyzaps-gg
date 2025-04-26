{# Counter‑Strike 2 dedicated server Salt state
   Assumptions:
     * Fedora 41 x86‑64 minimal install
     * Pillar key `cs2:gsl_token` contains the Game‑Server Login Token (GSLT)
     * Desired install dir: /home/steam/cs2-ds
#}

{% set gsl_token = salt['pillar.get']('cs2:gsl_token', '') %}
{% set metamod_url = salt['pillar.get']('cs2:metamod_url', 'https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1348-linux.tar.gz') %}

# ---------------------------------------------------------------------------
# Ensure firewalld package & service installed and running
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
# System packages & build tools
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
        - wget
        - unzip

# ---------------------------------------------------------------------------
# Steam user account
# ---------------------------------------------------------------------------
steam-user:
  user.present:
    - name: steam
    - shell: /bin/bash
    - home: /home/steam
    - createhome: True

# ---------------------------------------------------------------------------
# SteamCMD installation
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
# Install / update CS2 dedicated server
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

# ---------------------------------------------------------------------------
# 6. Metamod:Source installation
# ---------------------------------------------------------------------------
/opt/steamcmd/metamod.tar.gz:
  file.managed:
    - source: {{ metamod_url }}
    - user: steam
    - group: steam
    - mode: 0644
    - skip_verify: True

metamod-install:
  cmd.run:
    - name: |
        tar -xf /opt/steamcmd/metamod.tar.gz
    - runas: steam
    cwd: /home/steam/cs2-ds/game/csgo
    - require:
        - cmd: cs2-server-install
        - file: /opt/steamcmd/metamod.tar.gz
    - unless: test -f /home/steam/cs2-ds/game/csgo/addons/metamod/metamod/bin/linux64/metamod.2.csgo.so

metamod-update-gameinfo-config:
  file.blockreplace:
    - name: /home/steam/cs2-ds/game/csgo/gameinfo.gi
    - user: steam
    - marker_start: "Game_LowViolence        csgo_lv // Perfect World content override"
    - marker_end: "Game    csgo"
    - content: |
        Game    csgo/addons/metamod
    - append_if_not_found: True
