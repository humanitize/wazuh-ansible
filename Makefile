.PHONY: help deploy check ping test-connection clean

# Default target
help:
	@echo "Wazuh Ansible Deployment Makefile"
	@echo "=================================="
	@echo ""
	@echo "Available targets:"
	@echo "  make ping            - Test SSH connectivity to all hosts"
	@echo "  make check           - Run ansible-playbook in check mode (dry-run)"
	@echo "  make deploy          - Deploy Wazuh to all servers"
	@echo "  make deploy-indexer  - Deploy only indexer cluster"
	@echo "  make deploy-manager  - Deploy only manager nodes"
	@echo "  make deploy-dashboard - Deploy only dashboard"
	@echo "  make clean           - Clean up Ansible retry files"
	@echo ""

# Test SSH connectivity to all hosts
ping:
	@echo "Testing SSH connectivity to all hosts..."
	ansible -i inventory all -m ping

# Alias for ping
test-connection: ping

# Run playbook in check mode (dry-run, no changes made)
check:
	@echo "Running deployment in check mode (dry-run)..."
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --check

# Full deployment to all servers
deploy:
	@echo "Deploying Wazuh to all servers..."
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml

# Deploy only indexer cluster
deploy-indexer:
	@echo "Deploying Wazuh indexer cluster..."
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --tags generate-certs
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --limit wi_cluster

# Deploy only manager nodes
deploy-manager:
	@echo "Deploying Wazuh manager nodes..."
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --limit manager,worker

# Deploy only dashboard
deploy-dashboard:
	@echo "Deploying Wazuh dashboard..."
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --limit dashboard

# Clean up retry files
clean:
	@echo "Cleaning up Ansible retry files..."
	find . -name "*.retry" -type f -delete
	@echo "Done!"
