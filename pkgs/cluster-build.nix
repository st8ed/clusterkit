{ pkgs, jq }:
pkgs.writeShellApplication {
  name = "cluster-build";
  runtimeInputs = [ jq ];
  text = ''
    CLUSTER_FLAKE=''${CLUSTER_FLAKE:-.}
    BUILD_DIR=./build
    NIX_OPTS=--no-warn-dirty
    
    nodes="$(nix $NIX_OPTS eval \
        "$CLUSTER_FLAKE#cluster.config.nodes" \
        --apply 'x: (builtins.concatStringsSep " " (builtins.attrNames x))' \
        \
        | tr -d '"'
    )"
    
    echo "Cluster nodes: $nodes"
    
    echo "Building node secrets"
    generators="$(nix $NIX_OPTS build \
        "$CLUSTER_FLAKE#cluster.config.build.secrets"\
         --no-link --json | jq -r .[0].outputs.out
     )"
    mkdir -p "$BUILD_DIR/secrets"

    for node in $nodes; do
        secrets="$BUILD_DIR/secrets/secrets.$node.yaml"
        [ -f "$secrets" ] || touch "$secrets"

        generator_latest="$(readlink -f "$generators"/bin/build-secrets-"$node")"
        generator_current="$(readlink -f "$BUILD_DIR"/build-secrets/bin/build-secrets-"$node" || exit 0)"

        if [ "$(md5sum "$generator_latest")" != "$(md5sum "$generator_current")" ]; then
            echo "Building secrets for '$node' in '$secrets'"
            "$generator_latest" "$secrets"
            
            git add "$secrets"
        fi
    done
    
    ln -sfT "$generators" "$BUILD_DIR"/build-secrets
    
    mkdir -p "$BUILD_DIR"/systems
    
    echo "Building systems"
    nix $NIX_OPTS build \
        --profile "$BUILD_DIR/systems/profile" \
        "$CLUSTER_FLAKE#cluster.config.build.systems"
  '';
}
