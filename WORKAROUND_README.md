# Temporary Workaround for Vulnerability Detection

**Status:** Ready to apply (not yet applied)
**Version:** Wazuh 4.14.0-rc2
**Issue:** Indexer-connector authentication bug
**Solution:** Use admin certificates temporarily

---

## Problem Summary

Wazuh 4.14.0-rc2 has a bug where the indexer-connector cannot authenticate with the Wazuh Indexer using node certificates, preventing vulnerability detection data from syncing to the dashboard.

**Error:** `indexer-connector: WARNING: No available server`

**Impact:**
- ❌ Dashboard vulnerability module not working
- ✅ Vulnerability detection IS working locally (6.9GB CVE feed downloaded)
- ✅ All other SIEM features fully operational

---

## Workaround Strategy

**Replace node certificates with admin certificates** for the indexer-connector.

**Why this works:**
- Node certificates get HTTP 401 Unauthorized from indexer
- Admin certificates authenticate successfully (we tested this)
- This bypasses the RC bug while maintaining encrypted connections

**Safety:**
- ✅ Internal network only (indexers not internet-exposed)
- ✅ Still uses TLS encryption
- ✅ Temporary until Wazuh 4.14.1 stable
- ✅ Fully reversible with Git

---

## Prerequisites

Before applying:

1. **Git tag created:** `before-ssl-workaround` (✅ Done)
2. **All changes committed** (✅ Done)
3. **Backups will be created automatically** by the playbook

---

## How to Apply

```bash
# Apply the workaround
cd /Users/seba/Documents/projects/humanitize/wazuh-ansible
ansible-playbook -i inventory playbooks/workaround-use-admin-cert.yml
```

**What the playbook does:**
1. Creates backups of current ossec.conf and certificates
2. Fetches admin certificates from indexer (wi1)
3. Replaces node certificates with admin certificates
4. Updates ossec.conf to reference admin certs
5. Restarts Wazuh Manager
6. Verifies indexer-connector status
7. Creates revert script

**Expected result:** Indexer-connector should show "initialized successfully" in logs

---

## How to Revert

### Method 1: Git Checkout (Recommended)

```bash
# Revert to clean state
git checkout before-ssl-workaround

# Re-deploy to restore original configuration
ansible-playbook -i inventory site.yml
```

### Method 2: Use Generated Revert Script

```bash
# On manager nodes
/var/ossec/REVERT_ADMIN_CERT_WORKAROUND.sh
```

### Method 3: Manual Rollback

```bash
# Find and restore most recent backup
ls -t /var/ossec/etc/ossec.conf.backup-admin-cert-*
cp /var/ossec/etc/ossec.conf.backup-admin-cert-XXXXXX /var/ossec/etc/ossec.conf

# Restore certificate backups
ls -td /etc/pki/filebeat/backup-*
cp /etc/pki/filebeat/backup-XXXXXX/* /etc/pki/filebeat/

# Restart
/var/ossec/bin/wazuh-control restart
```

---

## When to Revert

**IMPORTANT:** Revert this workaround after upgrading to Wazuh stable:

1. **When Wazuh 4.14.1 stable is released** (expected 1-4 weeks)
2. **OR when upgrading to Wazuh 4.15.0+**

### Upgrade and Revert Process

```bash
# 1. Check for new stable release
apt-cache policy wazuh-manager

# 2. Upgrade Wazuh
ansible-playbook -i inventory playbooks/upgrade-to-stable-X.X.X.yml

# 3. Revert the workaround
git checkout before-ssl-workaround
ansible-playbook -i inventory site.yml

# 4. Verify normal operation
tail -f /var/ossec/logs/ossec.log | grep "IndexerConnector initialized successfully"
```

---

## Verification After Applying

### Check Logs
```bash
# Should see: "IndexerConnector initialized successfully"
ansible -i inventory manager -m shell -a "tail -50 /var/ossec/logs/ossec.log | grep -i indexer-connector" -b

# Should NOT see: "No available server" or "401"
```

### Check Dashboard
1. Log into Wazuh dashboard: https://10.250.32.110
2. Navigate to **Vulnerability Detection** module
3. Should see vulnerability data for agents

### Check Indices
```bash
# Should see vulnerability data being indexed
ansible -i inventory wi1 -m shell -a "curl -k -s --cert /etc/wazuh-indexer/certs/admin.pem --key /etc/wazuh-indexer/certs/admin-key.pem 'https://10.250.32.113:9200/_cat/indices?v' | grep vulnerab" -b
```

---

## Files Modified by Workaround

### On Manager/Worker Nodes

**Configuration:**
- `/var/ossec/etc/ossec.conf` - Updated to use admin certs
- Backup: `/var/ossec/etc/ossec.conf.backup-admin-cert-TIMESTAMP`

**Certificates:**
- `/etc/pki/filebeat/admin.pem` - New admin certificate
- `/etc/pki/filebeat/admin-key.pem` - New admin key
- `/etc/pki/filebeat/root-ca-indexer.pem` - New CA cert
- Backup: `/etc/pki/filebeat/backup-TIMESTAMP/`

**Scripts:**
- `/var/ossec/REVERT_ADMIN_CERT_WORKAROUND.sh` - Rollback script

---

## Alternative Workarounds (Not Recommended)

We also created these alternatives, but they're NOT recommended:

### Option 2: Disable SSL entirely
```bash
# playbooks/workaround-disable-indexer-ssl.yml
# Problem: Indexer rejects HTTP connections
# Result: Won't work
```

### Option 3: Disable indexer-connector
```bash
# playbooks/workaround-disable-indexer-connector.yml
# Effect: Stops error spam but dashboard still won't work
# Use case: Only if you don't need dashboard VD
```

---

## Security Considerations

**Is this safe?**

✅ **YES for internal network:**
- Indexers are NOT exposed to internet (only agents on ports 1514/1515)
- Still uses TLS encryption
- Admin cert is properly secured (mode 0640, root:wazuh)
- Temporary solution (will be reverted)

❌ **NO for public/untrusted networks:**
- Admin cert has elevated privileges
- Should only be used for indexer authentication in trusted environments

**Our situation:** SAFE
- Internal corporate network
- Indexers on private IPs (10.250.32.x)
- No internet exposure
- Temporary workaround

---

## Troubleshooting

### If Workaround Fails

**Symptoms:**
- Still seeing "No available server" errors
- Still seeing "401 Unauthorized" errors
- No "initialized successfully" message

**Possible causes:**
1. Admin cert wasn't copied correctly
2. ossec.conf not updated properly
3. Different bug in RC version

**Steps:**
```bash
# 1. Check certificate files exist and are readable
ansible -i inventory manager -m shell -a "ls -la /etc/pki/filebeat/admin*" -b

# 2. Check ossec.conf has admin cert paths
ansible -i inventory manager -m shell -a "grep -A 10 '<indexer>' /var/ossec/etc/ossec.conf" -b

# 3. Test admin cert manually
ansible -i inventory manager -m shell -a "curl -k -s --cert /etc/pki/filebeat/admin.pem --key /etc/pki/filebeat/admin-key.pem 'https://10.250.32.113:9200'" -b

# 4. Revert and try alternative
git checkout before-ssl-workaround
```

### If Dashboard Still Doesn't Show Data

**Wait 5-10 minutes** for data to sync, then:

```bash
# Force a vulnerability scan on an agent
ansible -i inventory manager -m shell -a "/var/ossec/bin/agent_control -u 001" -b

# Check if data is reaching indexer
ansible -i inventory wi1 -m shell -a "curl -k -s --cert /etc/wazuh-indexer/certs/admin.pem --key /etc/wazuh-indexer/certs/admin-key.pem 'https://10.250.32.113:9200/wazuh-states-vulnerabilities-wazuh/_count'" -b
```

---

## Git Workflow

### Current State

```
main branch (HEAD)
  └─ before-ssl-workaround (tag) ← Clean state for rollback
     └─ Workaround playbooks committed
        └─ (workaround will be applied to servers, not committed)
```

### After Applying Workaround

**Server state:** Modified (using admin certs)
**Git state:** Unchanged (tag points to clean config)

### Rolling Back

```bash
git checkout before-ssl-workaround
# This restores the clean configuration files
# Then re-deploy to apply clean config to servers
```

---

## Reminder Checklist

- [ ] Workaround applied and working
- [ ] Dashboard shows vulnerability data
- [ ] Calendar reminder set for checking Wazuh stable releases
- [ ] Team aware this is a temporary solution
- [ ] `/var/ossec/REMINDER_RE-ENABLE_INDEXER_CONNECTOR.txt` file present
- [ ] Know how to revert (git checkout before-ssl-workaround)

**When Wazuh 4.14.1+ stable is released:**
- [ ] Upgrade Wazuh
- [ ] Revert workaround (git checkout)
- [ ] Re-deploy clean configuration
- [ ] Verify vulnerability detection still works
- [ ] Remove this document

---

## Questions?

- **Q: Will this affect other Wazuh features?**
  A: No, only indexer-connector uses these certificates. Agents, Filebeat, etc. use different certs.

- **Q: What if I forget to revert after upgrading?**
  A: Not critical, but admin cert has more privileges than needed. Revert when convenient.

- **Q: Can I just leave this permanently?**
  A: No - admin cert should only be used temporarily. Proper node certs are more secure.

- **Q: Will agents be affected?**
  A: No - agents connect on ports 1514/1515 with their own certificates.

- **Q: Is the data encrypted during this workaround?**
  A: Yes - still using TLS/HTTPS, just with different certificates.

---

**Last Updated:** {{ ansible_date_time.date }}
**Status:** Ready to apply
**Approved By:** [Your name/approval needed]
