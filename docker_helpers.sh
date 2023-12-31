alias docker_helpers_rm_volume="rootlesskit rm -rf"

function docker_helpers_kill_by_name() {
  if [[ $# -gt 0 ]]
  then
    docker kill $(docker container ls -qf name="$1")
    shift
  fi
}

function docker_helpers_exec_remote() {
  server="$1"
  shift
  ssh "$server" "docker container ls --format '{{.Names}}'" 2>/dev/null | fzf | xargs -I% ssh -tt "$server" "docker exec -ti % $@"
} # stdin is broken

# example: docker_helpers_export_commands ghcr.io/osgeo/gdal
function docker_helpers_export_commands() {
    image="$1"
    (
    set -euo pipefail
    docker pull "$image"
    mapfile -t commands < <(combine \
        <(docker run --rm --entrypoint="" "$image" /bin/bash -c 'compgen -c' | sort -u) \
        not <(compgen -c | sort -u))
    printf "%s\n" "${commands[@]}" | fzf -m |
    while read command
    do
        wrapper="$HOME/bin/$command"
        if [ -f "$wrapper" ]
        then
            echo "Cannot override $wrapper"
            continue
        fi
cat << EOF > "$wrapper"
#!/bin/bash
exec docker run --rm --pid=host \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro -e DISPLAY=\$DISPLAY \
    -v "\$PWD":/host --workdir /host \
    -v /tmp:/tmp \
    --entrypoint="" "$image" "$command" "\$@"
EOF
    chmod +x "$wrapper"
    done
    )
}
