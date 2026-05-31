from pyinfra.operations import systemd, server

systemd.service(
    name="Enable automatic transactional updates",
    service="transactional-update.timer",
    running=True,
    enabled=True,
)
