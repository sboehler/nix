{ pkgs, ... }:
{
  users.users.silvio = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "lpadmin"
      "lxd"
      "networkmanager"
      "transmission"
      "wheel"
    ];
    uid = 1000;
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAHiEKQFsgRXTSzCQnDj/V1o8IeorD17qGOJT1oyZSUOlbE2dLeannUed/J1B9nuRniQlQkzwV+jNWONC3yDEM7ogADLYby9t290VYEm5xL+FpxYAdPpz8oXnGtDoITI8ebxqJry0Y2Sc3a/2lkDMKsRzACdEHS94e2VbDA28NsM8kew9A== silvi@winner"
    ];
  };
}
