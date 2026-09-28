# disko.nix — Option B: ZFS mirror on LUKS2, NVMe + SATA SSD
#
# WARNING: formatting DESTROYS all data on both disks. Back up your
# existing pool first (and verify the restore) before running this.
#
# Install with nixos-anywhere (copies the passphrase to /tmp/secret.key
# on the target before disko runs):
#   nixos-anywhere \
#     --disk-encryption-keys /tmp/secret.key <(read -rsp "LUKS passphrase: " p && echo -n "$p") \
#     --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
#     --flake .#homeserver \
#     root@homeserver
#
# Partition labels created (used for TPM enrollment later):
#   disk-nvme-ESP, disk-nvme-luks, disk-sata-ESP, disk-sata-luks
{
  disko.devices = {
    disk = {
      nvme = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-CT4000P3SSD8_2310E6B97FF9"; # ls -l /dev/disk/by-id/
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "2G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot"; # primary ESP, managed by lanzaboote
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypt-nvme";
                passwordFile = "/tmp/secret.key"; # provided by --disk-encryption-keys; only used while formatting
                settings = {
                  allowDiscards = true;
                  bypassWorkqueues = true;
                  crypttabExtraOpts = [ "tpm2-device=auto" ];
                };
                content = {
                  type = "zfs";
                  pool = "rpool";
                };
              };
            };
          };
        };
      };

      sata = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_4TB_S4CXNF0M310137V"; # ls -l /dev/disk/by-id/
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "2G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot-fallback"; # copy of /boot, kept in sync
                mountOptions = [
                  "umask=0077"
                  "nofail"
                ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypt-sata";
                passwordFile = "/tmp/secret.key";
                settings = {
                  allowDiscards = true;
                  bypassWorkqueues = true;
                  crypttabExtraOpts = [ "tpm2-device=auto" ];
                };
                content = {
                  type = "zfs";
                  pool = "rpool";
                };
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        mode = "mirror";
        options = {
          ashift = "12"; # 4K sectors; fixed at creation, cannot be changed later
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          dnodesize = "auto";
          atime = "off";
          mountpoint = "none";
          canmount = "off";
        };

        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options.mountpoint = "legacy";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };

          # Example for a database with 8K pages (PostgreSQL); adjust or remove.
          # "var/lib/postgresql" = {
          #   type = "zfs_fs";
          #   mountpoint = "/var/lib/postgresql";
          #   options = { mountpoint = "legacy"; recordsize = "16K"; };
          # };

          # Never mounted: keeps 10G free so a full pool can still be repaired
          # (zfs set refreservation=none rpool/reserved to release it).
          reserved = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              canmount = "off";
              refreservation = "10G";
            };
          };
        };
      };
    };
  };
}
