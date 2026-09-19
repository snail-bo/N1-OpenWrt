#!/bin/bash
set -euo pipefail

platform="${1:?platform is required}"
daede_revision=263503ae43a4336b753b44dd9ddd9553cf661071
argon_revision=ddefe5f05ca334dba10d2d65d25ebf14e986ee88
golang26_revision=3757065cca28b7fbe0e1667040412990770ca2f4
golang25_revision=e952b860128acc1e2c09caeff657109522c04d08
passwall_revision=3f4c9ce7fc507ba277a1c13af1aea046cae3f9d9
passwall_packages_revision=e73ad1c77a96fdaa498807ff7bc717dc92c349ea

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
rm -rf package/custom/daede package/custom/argon package/custom/amlogic \
       package/custom/passwall package/custom/passwall-packages
# The assembled daed 2026.09.12 source needs Go 1.26, while the HC5962
# PassWall build remains pinned to its proven Go 1.25 toolchain.
rm -rf feeds/packages/lang/golang
if [ "$platform" = hc5962 ]; then
  golang_revision="$golang25_revision"
else
  golang_revision="$golang26_revision"
fi
fetch_revision https://github.com/sbwml/packages_lang_golang.git "$golang_revision" feeds/packages/lang/golang
if [ "$platform" = hc5962 ]; then
  fetch_revision https://github.com/Openwrt-Passwall/openwrt-passwall.git \
    "$passwall_revision" package/custom/passwall
  fetch_revision https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git \
    "$passwall_packages_revision" package/custom/passwall-packages
  printf '%s\n' "$passwall_revision" > package/custom/passwall/.source-revision
  printf '%s\n' "$passwall_packages_revision" > package/custom/passwall-packages/.source-revision
else
  fetch_revision https://github.com/kenzok8/openwrt-daede.git "$daede_revision" package/custom/daede
  daed_version="$(sed -n 's/^PKG_VERSION:=//p' package/custom/daede/daed/Makefile)"
  daed_source="$(sed -n 's/^PKG_SOURCE:=//p' package/custom/daede/daed/Makefile)"
  daed_hash="$(sed -n 's/^PKG_HASH:=//p' package/custom/daede/daed/Makefile)"
  test -n "$daed_version"
  test -n "$daed_source"
  test -n "$daed_hash"
  printf '%s daed-version %s source %s sha256 %s\n' \
    "$daede_revision" "$daed_version" "$daed_source" "$daed_hash" \
    > package/custom/daede/.source-revision
fi
fetch_revision https://github.com/jerrykuku/luci-theme-argon.git "$argon_revision" package/custom/argon
if [ "$platform" = x86_64 ]; then
  # OpenWrt 24.10 provides wget through wget-ssl/wget-nossl variants and has no
  # selectable `wget` package symbol. Select the TLS variant explicitly so the
  # latest Argon package remains visible to Kconfig.
  sed -i \
    's/+USE_APK:wget-any +!USE_APK:wget/+wget-ssl/' \
    package/custom/argon/Makefile
  grep -q '^LUCI_DEPENDS:=+wget-ssl +jsonfilter$' package/custom/argon/Makefile
  printf '%s openwrt-24.10-dependency wget-ssl\n' "$argon_revision" \
    > package/custom/argon/.source-revision
else
  printf '%s\n' "$argon_revision" > package/custom/argon/.source-revision
fi

if [ "$platform" = n1 ]; then
  git clone --depth=1 https://github.com/ophub/luci-app-amlogic.git package/custom/amlogic
fi

# Avoid stale or conflicting implementations from feeds before feeds install.
rm -rf \
  feeds/luci/applications/luci-app-daed \
  feeds/luci/applications/luci-app-daede \
  feeds/packages/net/dae \
  feeds/packages/net/daed

if [ "$platform" = hc5962 ]; then
  rm -rf \
    feeds/luci/applications/luci-app-passwall \
    feeds/luci/applications/luci-app-passwall2 \
    feeds/packages/net/sing-box \
    feeds/packages/net/chinadns-ng \
    feeds/packages/net/dns2socks \
    feeds/packages/net/microsocks \
    feeds/packages/net/tcping \
    feeds/packages/net/v2ray-geodata
fi

echo "==> Argon theme source: $argon_revision"
echo "==> Go toolchain source: $golang_revision"
if [ "$platform" = hc5962 ]; then
  echo "==> PassWall source: $passwall_revision"
  echo "==> PassWall packages source: $passwall_packages_revision"
else
  echo "==> daed package source: $daede_revision"
fi
