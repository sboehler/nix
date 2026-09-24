{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment = {
    systemPackages = with pkgs; [
      isync
    ];
  };

  sops = {
    secrets = {
      imap_password = { };
      imap_user = { };
    };
    templates = {
      mbsync_config = {
        content = ''
          IMAPAccount fastmail
          Host imap.fastmail.com
          Port 993
          User ${config.sops.placeholder.imap_user}
          Pass ${config.sops.placeholder.imap_password}
          TLSType IMAPS

          IMAPStore fastmail-remote
          Account fastmail

          MaildirStore fastmail-local
          Inbox /data/backup/emails/${config.sops.placeholder.imap_user}/INBOX
          Path /data/backup/emails/${config.sops.placeholder.imap_user}/
          Subfolders Verbatim

          Channel fastmail-backup
          Far :fastmail-remote:
          Near :fastmail-local:
          # The asterisk tells mbsync to catch all folders/labels
          Patterns * !"Spam" !"Trash"
          # Automatically creates folders locally if they exist remotely
          Create Near
          # Syncs additions, deletions, and flag changes
          Sync Pull
          # Finalizes deletions locally
          Expunge Near
          SyncState *
        '';
        owner = config.users.users.silvio.name;
      };
    };
  };

  systemd = {
    services = {
      mbsyncd = {
        description = "mbsync";
        serviceConfig = {
          User = "silvio";
          Type = "oneshot";
          ExecStart = "${pkgs.isync}/bin/mbsync -a -c ${config.sops.templates.mbsync_config.path}";
        };
      };
    };
    timers = {
      mbsyncd = {
        description = "mbsyncd timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
        };
      };
    };
  };
}
