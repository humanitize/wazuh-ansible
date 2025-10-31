.PHONY: help deploy check ping test-connection clean change-password fix-filebeat

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
	@echo "  make change-password - Change admin password"
	@echo "  make fix-indexer-compat - Fix indexer Filebeat 7.x compatibility"
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

# Deploy only indexer cluster (all 3 indexer nodes)
deploy-indexer:
	@echo "Deploying Wazuh indexer cluster (wi1, wi2, wi3)..."
	@echo "Note: This will deploy all indexer nodes in the wi_cluster group"
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --limit wi1,wi_cluster

# Deploy only manager nodes (both master and worker)
deploy-manager:
	@echo "Deploying Wazuh manager nodes (manager + worker)..."
	@echo "Note: This will deploy both master and worker manager nodes"
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --limit manager,worker

# Deploy only dashboard (single dashboard node)
deploy-dashboard:
	@echo "Deploying Wazuh dashboard..."
	@echo "Note: This will deploy only the dashboard node"
	ansible-playbook -i inventory playbooks/wazuh-production-ready.yml --limit dashboard

# Change admin password
change-password:
	@echo "Changing Wazuh admin password..."
	@echo "You will be prompted to enter the new password twice for confirmation"
	ansible-playbook -i inventory playbooks/change-admin-password.yml

# Fix indexer compatibility with Filebeat 7.x
fix-indexer-compat:
	@echo "Fixing Wazuh Indexer compatibility with Filebeat 7.x..."
	@echo "This resolves the '_type parameter' error"
	ansible-playbook -i inventory playbooks/fix-indexer-filebeat-compatibility.yml

# Clean up retry files
clean:
	@echo "Cleaning up Ansible retry files..."
	find . -name "*.retry" -type f -delete
	@echo "Done!"
