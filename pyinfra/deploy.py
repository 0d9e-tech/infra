from pathlib import Path
from pyinfra.operations import systemd, server, files
from pyinfra.operations.util import any_changed
from pyinfra.facts.server import Hostname
from pyinfra import host

DEPLOY_DIR = Path(__file__).resolve().parent # the directory that contains this script

reload_ops = []  # everything that requires a systemd reload

systemd.service(
    name="Auto updates",
    service="transactional-update.timer",
    running=True,
    enabled=True,
)

disk_uuid = {"experiler": "97b5f756-35ed-4d7c-afad-c2dd442cd5ff"}.get(
    host.get_fact(Hostname)
)

if disk_uuid:
    files.line(
        name="Enable PCIe", # Disks are connected over PCIe
        path="/boot/efi/extraconfig.txt",
        line="dtparam=pciex1",
        present=True,
    )

for target in ["all", "default"]:
    files.line(
        name=f"Disable rp_filter ({target} conf)", # fixes containers not being reachable
        path="/etc/sysctl.d/99-podman-rp-filter.conf",
        line=f"net.ipv4.conf.{target}.rp_filter=0",
        present=True,
    )

files.sync(
    name="Sync Caddy build context",
    src=str(DEPLOY_DIR / "containers/blank-caddy"),
    dest="/opt/caddy-build",
)

server.shell(
    name="Build Caddy image",
    commands=["podman build -t localhost/custom-caddy:latest /opt/caddy-build"],
)

for directory in ["/srv/caddy-data/data", "/srv/caddy-data/config"]:
    files.directory(path=directory, present=True)

files.put(
    src=str(DEPLOY_DIR / "containers/blank-caddy/Caddyfile"),
    dest="/srv/caddy-data/config/Caddyfile",
)

reload_ops.append(
    files.put(
        src=str(DEPLOY_DIR / "services/caddy.network"),
        dest="/etc/containers/systemd/caddy.network",
    )
)

reload_ops.append(
    files.put(
        src=str(DEPLOY_DIR / "services/caddy.container"),
        dest="/etc/containers/systemd/caddy.container",
    )
)

if disk_uuid:
    reload_ops.append(
        files.template(
            name="Template the data mount service",
            src=str(DEPLOY_DIR / "services/data.mount.j2"),
            dest="/etc/systemd/system/mnt.mount",
            disk_uuid=disk_uuid,  # this is a jinja variable
        )
    )

systemd.daemon_reload(
    name="Reload systemd for new mount unit",
    _if=any_changed(*reload_ops),
)

if disk_uuid:
    systemd.service(
        name="Enable and mount /mnt",
        service="mnt.mount",
        running=True,
        enabled=True,
    )
