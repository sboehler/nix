{ config, pkgs, ... }:

# see https://xeiaso.net/blog/prometheus-grafana-loki-nixos-2020-11-20/
{
  services.grafana = {
    enable = true;
    openFirewall = true;
    settings = {
      server = {
        domain = "shuttle.tortoise-inconnu.ts.net";
        http_port = 2342;
        http_addr = "100.64.0.1";
      };
      security = {
        secret_key = config.sops.secrets.grafana_secret_key.path;
      };
    };
  };

  sops = {
    secrets = {
      grafana_secret_key = { };
    };
  };

  services.prometheus = {
    enable = true;
    port = 9001;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9002;
      };
    };
    scrapeConfigs = [
      {
        job_name = "shuttle";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
    ];
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3030;
      };
      common = {
        ring = {
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
        };
        replication_factor = 1;
        path_prefix = "/var/lib/loki";
      };
      schema_config.configs = [
        {
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      storage_config.filesystem.directory = "/var/lib/loki/chunks";
      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
    };
  };

  # Grafana Alloy reads the systemd journal and forwards it to Loki
  services.alloy.enable = true;

  environment.etc."alloy/config.alloy".text = ''
    loki.write "local" {
      endpoint {
        url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push"
      }
    }

    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
    }

    loki.source.journal "read" {
      forward_to    = [loki.write.local.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = { job = "systemd-journal" }
    }
  '';

  services.grafana.provision.datasources.settings.datasources = [
    {
      name = "Prometheus";
      type = "prometheus";
      access = "proxy";
      url = "http://127.0.0.1:${toString config.services.prometheus.port}";
      uid = "prometheus";
      isDefault = true;
    }
    {
      name = "Loki";
      type = "loki";
      access = "proxy";
      url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
    }
  ];

  services.grafana.provision.dashboards.settings = {
    apiVersion = 1;
    providers = [
      {
        name = "shuttle";
        options.path = pkgs.writeTextDir "network-traffic.json" (
          builtins.toJSON {
            title = "Network traffic";
            uid = "shuttle-network-traffic";
            schemaVersion = 39;
            time = {
              from = "now-6h";
              to = "now";
            };
            panels = [
              {
                id = 1;
                title = "Network traffic per interface";
                type = "timeseries";
                datasource = {
                  type = "prometheus";
                  uid = "prometheus";
                };
                gridPos = {
                  x = 0;
                  y = 0;
                  w = 24;
                  h = 12;
                };
                fieldConfig = {
                  defaults = {
                    unit = "Bps";
                    custom.fillOpacity = 10;
                  };
                  overrides = [ ];
                };
                targets = [
                  {
                    refId = "A";
                    expr = "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])";
                    legendFormat = "{{device}} RX";
                  }
                  {
                    refId = "B";
                    expr = "-rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])";
                    legendFormat = "{{device}} TX";
                  }
                ];
              }
            ];
          }
        );
      }
    ];
  };

  # # nginx reverse proxy
  # services.nginx = {
  #   enable = true;
  #   virtualHosts.${config.services.grafana.domain} = {
  #     locations."/" = {
  #       proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
  #       proxyWebsockets = true;
  #       extraConfig = ''
  #         proxy_set_header Host ${config.services.grafana.domain};
  #       '';
  #     };
  #   };
  # };
}
