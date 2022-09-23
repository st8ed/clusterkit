{ pkgs, terraform, terraform-providers }:
let
  terraform-provider-libvirt = terraform-providers.libvirt.override rec {
    version = "0.6.12";
    rev = "v${version}";
        sha256 = "sha256-1l+ARrXHxtSdnQfYV/6gw3BYHVH8NN4pi+Ttk1nwF88=";
        vendorSha256 = "sha256-OJa8pQgf5PlECZZkFV9fyCOdh6CrregY1BWycx7JPFE=";
  };

in pkgs.writeShellApplication {
  name = "cluster-deploy";
  runtimeInputs = [ (terraform.withPlugins (p: [
    terraform-provider-libvirt
    p.null
    p.external
    p.local
    p.aws
    p.tls
  ])) ];
  text = ''
    operation=''${1:-apply}
    shift 1

    CLUSTER_FLAKE=''${CLUSTER_FLAKE:-.}
    STATE_DIR=./state
    NIX_OPTS=--no-warn-dirty
    
    echo "Building cluster.tf"
    nix $NIX_OPTS build \
        "$CLUSTER_FLAKE#cluster.config.deployments.resourcePackage" \
        -o "$STATE_DIR/cluster.tf"
        
    echo "Running Terraform"
    (cd "$STATE_DIR"; terraform "$operation" "$@") 
  '';
}
