{
  config,
  pkgs,
  ...
}:
{
  sops.secrets."prober7_id" = { };
  systemd = {
    services = {
      prober7 = {
        description = "ping prober7";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "prober7" ''
            TOKEN=$(cat ${config.sops.secrets."prober7_id".path})
            ${pkgs.curl}/bin/curl -s -o /dev/null \
              http://prober7-sink.zekjur.net:42070/lightprobe/$TOKEN \
              http://prober7-sink6.zekjur.net:42070/lightprobe/$TOKEN
          '';
        };
      };
    };
    timers = {
      prober7 = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* *:*:00";
          Unit = "prober7.service";
          AccuracySec = "1ms";
        };
      };
    };
  };
}
