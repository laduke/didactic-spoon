# didactic-spoon

# run
go into ./workspace 

Make a `.env` with 

``` shell
export ZEROTIER_CENTRAL_TOKEN=
export TF_VAR_vultr_token="
export TF_VAR_pvt_key="/Users/you/.ssh/vultr"
export TF_VAR_pub_key="/Usersyou/.ssh/vultr.pub"
```

`source .env`

`terraform apply`

when ansible fails `terraform apply again`


# Terraform 

Create the Virtual Machines, ZeroTier Networks, ZeroTier Identities. 
Shove identities into Ansible, Create inventory.cfg for Ansible

# Ansible - bleh

## Configure

Install ZeroTier, install Identities, configure firewall

## asdfasdf
some of the ansible playbooks are not terraform dependent. 

`ansible-playbook -u root -i inventory.cfg --private-key /Users/travis/.ssh/vultr -e 'pub_key=/Users/travis/.ssh/vultr.pub' install-stuff.yml`


