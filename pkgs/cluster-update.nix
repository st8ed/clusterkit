{ pkgs, lib, kubectl }:
pkgs.writeShellApplication {
  name = "cluster-update";
  runtimeInputs = [ kubectl ];
  text = ''
    while IFS=, read -r node pool; do
        #shellcheck disable=SC2002
        correct_pool="$(
            cat ./build/systems/profile/metadata.json | jq ".pools | to_entries | .[] |  select(.value.nodes | contains([\"$node\"])) | .key" | tr -d '"'
        )"

        if [ "$pool" != "$correct_pool" ]; then
            echo "$node: updating pool label to $correct_pool"
            
            kubectl patch node "$node" -p '{"metadata": {"labels": {"node-restriction.kubernetes.io/pool": "'"$correct_pool"'"}}}'
        else
            echo "$node: pool label OK: $correct_pool"
       fi
    done< <(kubectl get nodes \
        -o=jsonpath='{range .items[*]}{.metadata.name}{","}{.metadata.labels.node-restriction\.kubernetes\.io/pool}{"\n"}{end}'
    )
  '';
}
