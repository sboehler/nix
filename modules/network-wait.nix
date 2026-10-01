{ pkgs, lib, ... }:
let
  # Any one of these resolving is enough, so a single provider having a bad
  # day can't hold up a backup.
  probeHosts = [
    "one.one.one.one"
    "dns.google"
  ];
  timeoutSec = 300;
in
{
  # Every Persistent= timer on this box fires the instant we come back from
  # suspend, and at that moment the main NIC (an RTL8156 on USB) is still
  # re-enumerating and dhcpcd has not re-applied the lease, so anything that
  # needs the network dies on "Name or service not known".
  #
  # The usual After=network-online.target does not help: that target was
  # reached once at boot and stays active across a suspend/resume cycle, so on
  # wake it is already satisfied and gates nothing. (services.restic already
  # orders itself after it, which is exactly why those backups still failed.)
  #
  # So gate on something that is re-evaluated every time instead. Type=oneshot
  # *without* RemainAfterExit drops back to inactive once it succeeds, which
  # means every unit that Requires= it pulls in a fresh run and blocks on the
  # real state of the network rather than on a stale target.
  systemd.services.wait-for-network = {
    description = "Wait until the network is usable again";
    after = [
      "network.target"
      "nss-lookup.target"
      "dhcpcd.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      TimeoutStartSec = timeoutSec + 30;
      ExecStart = pkgs.writeShellScript "wait-for-network" ''
        deadline=$(( $(date +%s) + ${toString timeoutSec} ))

        while :; do
          if [ -n "$(${pkgs.iproute2}/bin/ip route show default)" ]; then
            for host in ${lib.concatStringsSep " " probeHosts}; do
              if ${pkgs.getent}/bin/getent hosts "$host" > /dev/null; then
                exit 0
              fi
            done
          fi

          if [ "$(date +%s)" -ge "$deadline" ]; then
            echo "no default route or no working DNS after ${toString timeoutSec}s" >&2
            exit 1
          fi

          sleep 2
        done
      '';
    };
  };
}
