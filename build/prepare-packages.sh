#!/bin/bash
set -euo pipefail

platform="${1:?platform is required}"
daede_revision=542e86e84e4baec51070e43ab810d0788ebf41d7
argon_revision=ddefe5f05ca334dba10d2d65d25ebf14e986ee88
golang24_revision=94dd0f5793debfee007f0581509640c392de7188
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
# daed needs Go 1.24, while the HC5962 PassWall build's sing-box 1.14
# needs Go 1.25. Keep separate pinned toolchains so working builds stay stable.
rm -rf feeds/packages/lang/golang
if [ "$platform" = hc5962 ]; then
  golang_revision="$golang25_revision"
else
  golang_revision="$golang24_revision"
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
  # Keep the package's original backend source, web asset and mirror hash as a
  # tested set. Overriding only PKG_SOURCE_VERSION breaks the bundled Web UI.
  # Export BPF variables before the first `go generate ./...` invocation.
  python3 - <<'PY'
from pathlib import Path

path = Path('package/custom/daede/daed/Makefile')
text = path.read_text()
marker = "\t\tgo mod tidy ; \\\n"
prefix = (
    "\t\texport \\\n"
    "\t\tBPF_CLANG=\"$(CLANG)\" \\\n"
    "\t\tBPF_STRIP_FLAG=\"-strip=$(LLVM_STRIP)\" \\\n"
    "\t\tBPF_CFLAGS=\"$(DAE_CFLAGS)\" \\\n"
    "\t\tBPF_TARGET=\"bpfel,bpfeb\" \\\n"
    "\t\tBPF_TRACE_TARGET=\"$(GO_ARCH)\" ; \\\n"
)
if marker not in text:
    raise SystemExit('go mod tidy line not found')
path.write_text(text.replace(marker, prefix + marker, 1))
PY
  daed_source_revision="$(sed -n 's/^PKG_SOURCE_VERSION:=//p' package/custom/daede/daed/Makefile)"
  daed_web_version="$(sed -n 's/^PKG_WEB_VERSION:=//p' package/custom/daede/daed/Makefile)"
  test -n "$daed_source_revision"
  test -n "$daed_web_version"
  printf '%s daed-package %s daed-source %s daed-web %s\n' \
    "$daede_revision" "$daede_revision" "$daed_source_revision" "$daed_web_version" \
    > package/custom/daede/.source-revision
fi
fetch_revision https://github.com/jerrykuku/luci-theme-argon.git "$argon_revision" package/custom/argon
printf '%s\n' "$argon_revision" > package/custom/argon/.source-revision

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
