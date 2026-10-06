# server-playbooks

Ansible for the VPS that [vps-terraform](https://github.com/zgfun/vps-terraform)
creates. A hobby setup, not a production one: one Ubuntu 24.04 box, hardened,
running a small Docker stack behind Caddy, with nightly backups.

| Role        | What it does                                                                 |
|-------------|-------------------------------------------------------------------------------|
| `base`      | timezone, unattended security upgrades, baseline packages, `deploy` user with sudo and SSH keys |
| `hardening` | sshd keys-only and no root, ufw deny-by-default with 22/80/443, fail2ban on sshd |
| `docker`    | Docker Engine + compose plugin from Docker's repo, bounded container logs, deploy user in the docker group |
| `app`       | `/opt/stack` with Caddy (auto TLS), Uptime Kuma and a whoami container, rendered from templates |
| `backup`    | nightly tar of the Docker volumes, 14 days retention, via cron |

## Use

```bash
# collections used by the roles
ansible-galaxy collection install -r requirements.yml

# inventory: either edit inventory/hosts.yml or use the one Terraform wrote
ansible-playbook -i ../vps-terraform/generated/inventory.yml site.yml

# only one concern
ansible-playbook site.yml --tags hardening

# a server that cloud-init did not prepare (other providers): create the deploy user first, as root
ansible-playbook bootstrap.yml -u root
```

Settings live in `group_vars/all.yml`. Secrets do not: use `ansible-vault` or
environment variables.

## Tests

```bash
ansible-lint                 # production profile, 0 warnings
./tests/smoke.sh             # needs Docker
```

`tests/smoke.sh` starts a throwaway Ubuntu 24.04 container, runs `site.yml`
against it over the Docker connection plugin, then runs it again and fails if
the second run changed anything. Service-level tasks (starting daemons,
enabling ufw) are tagged `service` and skipped there, because a plain
container has no systemd. Both checks run in GitHub Actions.

## Decisions

- **Never lock yourself out.** SSH is allowed in ufw before the firewall is
  enabled, the sshd config is validated with `sshd -t` before it is written,
  and the restart is a handler that only fires on change.
- **Handlers, not restarts.** Every service restart is a handler, so a no-op
  run touches nothing.
- **One compose file, rendered.** The stack is a template so the domain, email
  and versions come from `group_vars`, and the same role works for the next box.
- **Backups are boring on purpose.** A tar of the volumes to local disk with a
  retention loop. Shipping them off the box with rclone is the obvious next step
  and deliberately not done yet.
