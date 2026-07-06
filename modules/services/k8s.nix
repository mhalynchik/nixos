{ config, pkgs, vars, ... }:
{
  # Kubernetes local cluster (optional - disable if not needed)
  # services.kubernetes = {
  #   roles = [ "master" "node" ];
  #   masterAddress = "localhost";
  # };

  environment.systemPackages = with pkgs; [
    kubectx
    kubectl
    kubernetes-helm
    k9s
  ];

  environment.sessionVariables.KUBECONFIG = "${vars.homeDirectory}/.kube/config";
}
