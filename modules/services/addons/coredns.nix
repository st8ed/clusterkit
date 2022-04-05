{ pkgs, config, lib, clusterConfig, ... }:

with lib;

let
  cfg = clusterConfig.addons.coredns;
in
{
  # See https://github.com/coredns/deployment/blob/08c2b11241ef67b5d22d2020c00001ce0baec566/kubernetes/coredns.yaml.sed

  config = mkIf cfg.enable {
    services.kubernetes.addonManager.bootstrapAddons = {
      coredns-cr = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = {
          labels = {
            "addonmanager.kubernetes.io/mode" = "Reconcile";
            "kubernetes.io/name" = "CoreDNS";
            "kubernetes.io/cluster-service" = "true";
            "kubernetes.io/bootstrapping" = "rbac-defaults";
          };
          name = "system:coredns";
        };
        rules = [
          {
            apiGroups = [ "" ];
            resources = [ "endpoints" "services" "pods" "namespaces" ];
            verbs = [ "list" "watch" ];
          }
          {
            apiGroups = [ "" ];
            resources = [ "nodes" ];
            verbs = [ "get" ];
          }
          {
            apiGroups = [ "discovery.k8s.io" ];
            resources = [ "endpointslices" ];
            verbs = [ "list" "watch" ];
          }
        ];
      };

      coredns-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = {
          annotations = {
            "rbac.authorization.kubernetes.io/autoupdate" = "true";
          };
          labels = {
            "addonmanager.kubernetes.io/mode" = "Reconcile";
            "kubernetes.io/name" = "CoreDNS";
            "kubernetes.io/cluster-service" = "true";
            "kubernetes.io/bootstrapping" = "rbac-defaults";
          };
          name = "system:coredns";
        };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "system:coredns";
        };
        subjects = [
          {
            kind = "ServiceAccount";
            name = "coredns";
            namespace = "kube-system";
          }
        ];
      };
    };

    services.kubernetes.addonManager.addons = {
      coredns-sa = {
        apiVersion = "v1";
        kind = "ServiceAccount";
        metadata = {
          labels = {
            "addonmanager.kubernetes.io/mode" = "Reconcile";
            "kubernetes.io/cluster-service" = "true";
          };
          name = "coredns";
          namespace = "kube-system";
        };
      };

      coredns-cm = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          labels = {
            "addonmanager.kubernetes.io/mode" = cfg.reconcileMode;
            "kubernetes.io/cluster-service" = "true";
          };
          name = "coredns";
          namespace = "kube-system";
        };
        data = {
          Corefile = cfg.corefile;
        };
      };

      coredns-deploy = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          labels = {
            "addonmanager.kubernetes.io/mode" = cfg.reconcileMode;
            "kubernetes.io/cluster-service" = "true";
            "kubernetes.io/name" = "CoreDNS";
          };
          name = "coredns";
          namespace = "kube-system";
        };
        spec = {
          replicas = cfg.replicas;
          selector = {
            matchLabels = { "app.kubernetes.io/name" = "coredns"; };
          };
          strategy = {
            rollingUpdate = { maxUnavailable = 1; };
            type = "RollingUpdate";
          };
          template = {
            metadata = {
              labels = {
                "app.kubernetes.io/name" = "coredns";
              };
            };
            spec = {
              containers = [
                {
                  args = [ "-conf" "/etc/coredns/Corefile" ];
                  image = with cfg.image; "${imageName}:${imageTag}";
                  imagePullPolicy = "Never";
                  livenessProbe = {
                    httpGet = {
                      path = "/health";
                      port = 8080;
                      scheme = "HTTP";
                    };
                    initialDelaySeconds = 60;
                    timeoutSeconds = 5;
                    successThreshold = 1;
                    failureThreshold = 5;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/ready";
                      port = 8181;
                      scheme = "HTTP";
                    };
                  };
                  name = "coredns";
                  ports = [
                    {
                      containerPort = 53;
                      name = "dns";
                      protocol = "UDP";
                    }
                    {
                      containerPort = 53;
                      name = "dns-tcp";
                      protocol = "TCP";
                    }
                    {
                      containerPort = 9153;
                      name = "metrics";
                      protocol = "TCP";
                    }
                  ];
                  resources = {
                    limits = {
                      cpu = "100m";
                      memory = "200Mi";
                    };
                    requests = {
                      cpu = "100m";
                      memory = "200Mi";
                    };
                  };
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    capabilities = {
                      add = [ "NET_BIND_SERVICE" ];
                      drop = [ "all" ];
                    };
                    readOnlyRootFilesystem = true;
                  };
                  volumeMounts = [
                    {
                      mountPath = "/etc/coredns";
                      name = "config-volume";
                      readOnly = true;
                    }
                  ];
                }
              ];
              dnsPolicy = "Default";
              priorityClassName = "system-cluster-critical";
              nodeSelector = {
                "beta.kubernetes.io/os" = "linux";
              };
              serviceAccountName = "coredns";
              tolerations = [
                {
                  effect = "NoSchedule";
                  key = "node-role.kubernetes.io/master";
                  operator = "Equal";
                  value = "true";
                }
                {
                  key = "CriticalAddonsOnly";
                  operator = "Exists";
                }
              ];
              volumes = [
                {
                  configMap = {
                    items = [
                      {
                        key = "Corefile";
                        path = "Corefile";
                      }
                    ];
                    name = "coredns";
                  };
                  name = "config-volume";
                }
              ];
            };
          };
        };
      };

      coredns-svc = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          annotations = {
            "prometheus.io/port" = "9153";
            "prometheus.io/scrape" = "true";
          };
          labels = {
            "addonmanager.kubernetes.io/mode" = "Reconcile";
            "app.kubernetes.io/name" = "coredns";
            "kubernetes.io/cluster-service" = "true";
            "kubernetes.io/name" = "CoreDNS";
          };
          name = "coredns";
          namespace = "kube-system";
        };
        spec = {
          clusterIP = clusterConfig.dnsServiceAddress;
          ports = [
            {
              name = "dns";
              port = 53;
              targetPort = 53;
              protocol = "UDP";
            }
            {
              name = "dns-tcp";
              port = 53;
              targetPort = 53;
              protocol = "TCP";
            }
          ];
          selector = { "app.kubernetes.io/name" = "coredns"; };
        };
      };
    };

  };
}
        
