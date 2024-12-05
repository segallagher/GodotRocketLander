#!/bin/sh
echo -ne '\033c\033]0;LanderRLV2\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/LanderRLV2_64agents.x86_64" "$@"
