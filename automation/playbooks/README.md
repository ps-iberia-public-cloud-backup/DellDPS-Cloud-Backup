## Ansible installation

```
sudo dnf update -y
sudo dnf install -y epel-release
sudo dnf install ansible -y
```
## Ansible configuration
```
  ssh user@host
  ssh-keygen
  ssh-copy-id user@host
  sudo  echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user
```
  #### Lines added in inventory file  (a.k.a /etc/ansible/inventory)
```
  [DCI]
  10.0.0.4
```
  #### Lines added on ansible host files (/etc/ansible/hosts)
```
  [DCI]
  dcivm
```
## Playbook execution
```
ansible-playbook -i /etc/ansible/inventory automation/playbooks/setup.yaml
```