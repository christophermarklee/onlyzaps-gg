# onlyzaps-gg

## Initial Setup
```
sudo dnf install git
curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.repo | sudo tee /etc/yum.repos.d/salt.repo
sudo dnf install salt-minion
git clone https://github.com/christophermarklee/onlyzaps-gg.git
```

## Commands
```
sudo salt-call --file-root=/home/fedora/onlyzaps-gg/srv/salt --local state.test
sudo salt-call --file-root=/home/fedora/onlyzaps-gg/srv/salt --local state.apply
```