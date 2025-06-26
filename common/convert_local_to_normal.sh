#!/bin/bash

local_bundles_dir="/d/Projects/tmp/local-bundles"
normal_bundles_dir="/d/Projects/tmp/bundles"

mkdir -p "$normal_bundles_dir"

for file in "$local_bundles_dir"/local_*.bundle; do
    filename=$(basename "$file")
    if [[ $filename =~ ^local_[0-9]{8}_[0-9]{6}_(.+)$ ]]; then
        newname="${BASH_REMATCH[1]}"
        cp -f "$file" "$normal_bundles_dir/$newname"
        echo "已转换: $filename -> $newname"
    fi
done