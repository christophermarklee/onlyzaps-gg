# onlyzaps-gg

## Initial Setup
```
sudo dnf install git
curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.repo | sudo tee /etc/yum.repos.d/salt.repo
sudo dnf install salt-minion
git clone https://github.com/christophermarklee/onlyzaps-gg.git
ln -s onlyzaps-gg/srv/salt /srv/salt
ln -s onlyzaps-gg/srv/pillar /srv/pillar
sudo salt-call --local state.apply

## Commands
```
sudo salt-call --local state.apply
