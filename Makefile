SHELL:=/bin/bash

NODESLIST:=node1 node2
ALLSERVERSLIST:=controller ${NODESLIST}

# Create Vagrant VMs with SLURM configured on them
setup:
	vagrant up
	rm -f munge.key id_*

# make sure 'slurm' dir is writable for VMs
# start munge in VMs
# start slurmctld, wait many seconds for it to fully start
# start slurmd
start:
	find slurm -type d -exec chmod a+rwx {} \;
	#vagrant ssh controller -- -t 'sudo /etc/init.d/munge start; sleep 5' && \
	#vagrant ssh node1 -- -t 'sudo /etc/init.d/munge start; sleep 5' && \
	#vagrant ssh node2 -- -t 'sudo /etc/init.d/munge start; sleep 5' && \
	vagrant ssh controller -- -t 'sudo slurmctld; sleep 30' && \
	vagrant ssh node1 -- -t 'sudo slurmd; sleep 30' && \
	vagrant ssh node2 -- -t 'sudo slurmd; sleep 30' && \
	vagrant ssh controller -- -t 'sudo scontrol update nodename=node[1-2] state=resume; sinfo; sleep 5'

sinfo:
	vagrant ssh controller -- -t 'sinfo'

# might need this to fix node down state?
# fix:
# 	vagrant ssh controller -- -t 'sudo scontrol update nodename=node1 state=resume'
# 	vagrant ssh controller -- -t 'sudo scontrol update nodename=node2 state=resume'

# https://slurm.schedmd.com/troubleshoot.html
# https://github.com/dun/munge/blob/master/QUICKSTART
# munge log: /var/log/munge/munged.log
.ONESHELL:
test:
	@printf ">>> Checking munge keys on both machines\n"
	@vagrant ssh controller -- -t 'sudo md5sum /etc/munge/munge.key; sudo ls -l /etc/munge/munge.key'
	@vagrant ssh node1 -- -t 'sudo md5sum /etc/munge/munge.key; sudo ls -l /etc/munge/munge.key'
	@printf "\n\n>>> Checking if controller can contact node (network)\n"
	@vagrant ssh controller -- -t 'ping 10.10.10.4 -c1'
	@printf "\n\n>>> Checking if SLURM controller is running\n"
	@vagrant ssh controller -- -t 'scontrol ping'
	@printf "\n\n>>> Checking if slurmctld is running on controller\n"
	@vagrant ssh controller -- -t 'ps -el | grep slurmctld'
	@printf "\n\n>>> Checking cluster status\n"
	@vagrant ssh controller -- -t 'sinfo'
	@printf "\n\n>>> Checking if node can contact controller (network)\n"
	@vagrant ssh node1 -- -t 'ping 10.10.10.3 -c1'
	@printf "\n\n>>> Checking if node can contact SLURM controller\n"
	@vagrant ssh node1 -- -t 'scontrol ping'
	@printf "\n\n>>> Checking if slurmd is running on node\n"
	@vagrant ssh node1 -- -t 'ps -el | grep slurmd'
	@printf "\n\n>>> Running a test job\n"
	@vagrant ssh controller -- -t 'sbatch --wrap="hostname"'
	@printf "\n\n>>> Running another test job\n"
	@vagrant ssh controller -- -t 'sbatch /vagrant/job.sh'
	@printf "\n\n>>> Checking node status\n"
	@vagrant ssh controller -- -t 'scontrol show nodes'
	@printf "\n\n>>> Munge troubeshooting (encode and decode a credential)\n"
	@vagrant ssh controller -- -t 'munge -n | unmunge'
	@vagrant ssh node1 -- -t 'munge -n | unmunge'
	@vagrant ssh node1 -- -t 'munge -n | ssh controller unmunge'

# pull the plug on the VMs
stop:
	for server in ${ALLSERVERSLIST}; do \
		vagrant halt --force $$server; \
	done

# delete the VMs
remove:
	for server in ${ALLSERVERSLIST}; do \
		vagrant destroy $$server ; \
	done


# location of the SLURM default config generators for making new conf files
get-config-html:
	vagrant ssh controller -- -t 'cp /usr/share/doc/slurmctld/*.html /vagrant/'

# get rid of the SLURM log files
clean:
	find slurm -type f ! -name ".gitkeep" -exec rm -f {} \;
