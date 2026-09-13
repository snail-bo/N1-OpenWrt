#!/bin/bash
set -euo pipefail

platform="${1:?platform is required}"
daede_revision=542e86e84e4baec51070e43ab810d0788ebf41d7

fetch_revision() {
  local url="$1"
  local revision="$2"
  local destination="$3"
  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch --depth=1 origin "$revision"
  git -C "$destination" checkout -q --detach FETCH_HEAD
  test "$(git -C "$destination" rev-parse HEAD)" = "$revision"
}

mkdir -p package/custom
rm -rf package/custom/daede package/custom/amlogic
fetch_revision https://github.com/kenzok8/openwrt-daede.git "$daede_revision" package/custom/daede
printf '%s\n' "$daede_revision" > package/custom/daede/.source-revision

if [ "$platform" = n1 ]; then
  git clone --depth=1 https://github.com/ophub/luci-app-amlogic.git package/custom/amlogic
fi

# Avoid stale or conflicting implementations from feeds before feeds install.
rm -rf \
  feeds/luci/applications/luci-app-daed \
  feeds/luci/applications/luci-app-daede \
  feeds/packages/net/dae \
  feeds/packages/net/daed

echo "==> daed package source: $daede_revision"
