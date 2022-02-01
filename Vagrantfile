# -*- mode: ruby -*-
# vi: set ft=ruby :

#Define the list of machines
slurm_cluster = {
    :controller => {
        :hostname => "controller",
        :ipaddress => "10.10.10.3"
    },
    :node1 => {
        :hostname => "node1",
        :ipaddress => "10.10.10.4"
    },
    :node2 => {
        :hostname => "node2",
        :ipaddress => "10.10.10.5"
    }
}

# Provisioning inline script
# - Installs slurm-wlm package. Alternatively exists the slurm-llnl,
# but in Jan/2022, the last available version is the 19.05, while
# the slurm-wlm has as stable version the SLURM 20.11, and in active
# development the SLURM version 21.08. Source:
# https://launchpad.net/ubuntu/+source/slurm-wlm
# - Populate /etc/hosts with all the nodes
# - Configure the inter-node SSH access by creating a SSH Key Pair for
# the vagrant user and adding it as authorized on all nodes
$script = <<SCRIPT
# install SLURM
apt-get update
apt-get install -y -q vim slurm-wlm

# config SLURM
ln -sf /vagrant/slurm.conf /etc/slurm/slurm.conf

# Config Munge
if [ ! -f /vagrant/munge.key ]; then
    # generate the key to shared vagrant path to reuse in all nodes
    mungekey -k /vagrant/munge.key --verbose
fi
# reusing the key
# !! need cp -p or munge keys do not work
cp -p /vagrant/munge.key /etc/munge/
chown munge:munge /etc/munge/munge.key
chmod 0700 /etc/munge
chmod 0600 /etc/munge/munge.key

# populate hosts
echo "10.10.10.3    controller" >> /etc/hosts
echo "10.10.10.4    node1" >> /etc/hosts
echo "10.10.10.5    node2" >> /etc/hosts

# SSH Config based on:
# https://github.com/kikitux/vagrant-multimachine/blob/master/intrassh/Vagrantfile

# Generate the private key for vm-vm communication
# (only in the first node, the others share/use the same key)
[ -f /vagrant/id_vagrant_user ] || {
  ssh-keygen -b 2048 -t rsa -f /vagrant/id_vagrant_user -q -N ''
}
# Deploy key
[ -f /home/vagrant/.ssh/id_vagrant_user ] || {
    cp /vagrant/id_vagrant_user /home/vagrant/.ssh/id_vagrant_user
    chown vagrant:vagrant /home/vagrant/.ssh/id_vagrant_user
    chmod 0600 /home/vagrant/.ssh/id_vagrant_user
}
# Allow ssh passwordless
grep 'vagrant@node' ~/.ssh/authorized_keys &>/dev/null || {
  cat /vagrant/id_vagrant_user.pub >> /home/vagrant/.ssh/authorized_keys
  chmod 0600 /home/vagrant/.ssh/authorized_keys
}
# Exclude controller and node* from host checking
cat > /home/vagrant/.ssh/config <<EOF
Host controller node*
   StrictHostKeyChecking no
   UserKnownHostsFile=/dev/null
   IdentityFile=~/.ssh/id_vagrant_user
EOF
chown vagrant:vagrant /home/vagrant/.ssh/config
chmod 0600 /home/vagrant/.ssh/config
#autostart services
#systemctl enable munge
SCRIPT

Vagrant.configure("2") do |global_config|
    slurm_cluster.each_pair do |name, options|
        global_config.vm.define name do |config|
            #VM configurations
            config.vm.box = "ubuntu/hirsute64"
            config.vm.hostname = "#{name}"
            config.vm.network :private_network, ip: options[:ipaddress]

            #VM specifications
            config.vm.provider :virtualbox do |v|
                # v.customize ["modifyvm", :id, "--memory", "1024"]
                v.cpus = 1
                v.memory = 1024
            end

            #VM provisioning
            config.vm.provision :shell,
                :inline => $script
        end
    end
    # set the controller as the default machine when do "vagrant ssh"
    global_config.vm.define "controller", primary: true do |controller|
    end
end
