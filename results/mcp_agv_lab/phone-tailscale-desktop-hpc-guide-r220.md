# Phone Tailscale guide r220

Goal: phone can reach laptop, desktop, and HPC through the same tailnet.

1. Install Tailscale on iOS/Android and sign in with the same tailnet account.
2. In https://login.tailscale.com/admin/machines, approve the phone if approval is required.
3. Keep MagicDNS enabled. Use the Tailscale app to confirm the phone shows online.
4. Laptop tailnet: run tailscale status and tailscale ip -4 on the laptop. This task recorded the current status in tailscale-phone-hpc-probe-r220.json.
5. Desktop access: use the desktop tailnet IP 100.84.137.117. For RDP from phone, use Microsoft Remote Desktop to 100.84.137.117. For SSH, use Termius/Blink/JuiceSSH if sshd is enabled.
6. HPC access: historical route is 10.10.5.210/32. A subnet router must advertise this route and the admin console must approve it. Then phone SSH apps can connect to ssh user@10.10.5.210.
7. If HPC does not work from phone, check: route approved in admin console, subnet router online, ACL permits phone -> 10.10.5.210:22, and phone Tailscale is connected.
8. For stable devices, optionally disable key expiry in the admin console for laptop/desktop/HPC route machines.

Notes: mobile OS background limits may prevent other machines from reliably initiating long inbound sessions to the phone, but the phone can initiate sessions to desktop/HPC when Tailscale is connected.
