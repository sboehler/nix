# Partition labels created (used for TPM enrollment later):
#   disk-nvme-ESP, disk-nvme-luks
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
                mountpoint = "/boot"; # managed by lanzaboote
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
    };

    zpool = {
      # Single vdev on crypt-nvme -- no `mode`, which is disko's default for a
      # striped/single-disk pool.
      rpool = {
        type = "zpool";
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
