# pihole-iac

Pi-hole in Docker with host networking, run by a systemd unit. The same checkout
deploys both instances: the home LAN and the WireGuard VPN server (orion).

## Deploy

```bash
cp .env.bash.template .env.bash   # then edit, see below
INSTALL=true ENABLE_NOW=true ./create-systemd-service.sh
```

The unit is named after the checkout directory (`pihole-iac.service`) and reads
`.env.bash` each time it starts, so after editing it a
`sudo systemctl restart pihole-iac` is enough. Re-run the script only after
changing `SYSTEMD_REQUIRES`.

## Home vs VPN server

- **Home:** only `TZONE`. Pi-hole answers on every interface and the router keeps
  it off the internet.
- **VPN server:** it has a public IP, so uncomment the VPN block in `.env.bash`.
  DNS binds to `wg0` only, the web UI to `10.8.0.1:5380` and `:53443` (the
  host's own web server has 80/443), the NTP server is off, and the unit starts
  after `wg-quick@wg0`.

Check that nothing is listening publicly:

```bash
sudo ss -tulpn | grep pihole-FTL   # only 10.8.0.1, wg0's IPv6 address, 127.0.0.1 and ::1
```

## Firewall on the VPN server

The WireGuard firewall setup (see wgctl's README) only has `ufw route allow` rules. Those cover
traffic the server forwards between peers or to the internet, not traffic
addressed to the server itself, which ufw's default incoming policy drops. So
Pi-hole's ports need their own rules, limited to `wg0`:

```bash
sudo ufw allow in on wg0 to any port 53 comment 'pihole dns'
sudo ufw allow in on wg0 from 10.8.0.22 to any port 5380 proto tcp comment 'pihole web via caddy'
```

The web UI is served at `https://pihole-vpn.hugo-klepsch.tech/admin/` by the
internal Caddy, which is another VPN peer (`10.8.0.22`), not orion. Its
requests reach Pi-hole over `wg0` like any client's, so it needs the second
rule. The DNS record must point at the Caddy node: orion runs its own Caddy on
443, which answers 404 for this name. Allowing only Caddy's address keeps the
admin UI off the rest of the VPN. For direct access from any VPN client
instead, drop `from 10.8.0.22` and add 53443.

Test from a VPN client, e.g. `dig @10.8.0.1 example.com`. Tests run on the
server itself pass regardless of the firewall, because ufw always allows
loopback traffic.
