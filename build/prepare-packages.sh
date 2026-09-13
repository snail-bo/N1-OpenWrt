#!/bin/bash
set -euo pipefail

platform="${1:?platform is required}"
daede_revision=542e86e84e4baec51070e43ab810d0788ebf41d7
daed_source_revision=4a519fcbaa7004e50e80a309c68d6811596468cf
argon_revision=ddefe5f05ca334dba10d2d65d25ebf14e986ee88
golang_revision=94dd0f5793debfee007f0581509640c392de7188

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
rm -rf package/custom/daede package/custom/argon package/custom/amlogic
# daed's nested dae-core requires Go 1.24. Replace the iStoreOS 24.10
# Go 1.23 feed with sbwml's OpenWrt 24.10-compatible Go 1.24 package.
rm -rf feeds/packages/lang/golang
fetch_revision https://github.com/sbwml/packages_lang_golang.git "$golang_revision" feeds/packages/lang/golang
fetch_revision https://github.com/kenzok8/openwrt-daede.git "$daede_revision" package/custom/daede
# Keep daed on the package feed's matching source generation. Its wing module
# supports Go 1.23, while the nested dae-core module requires Go 1.24.
sed -i \
  -e "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=${daed_source_revision}/" \
  -e '/^PKG_MIRROR_HASH:=/d' \
  package/custom/daede/daed/Makefile
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
printf '%s daed-package %s daed-source %s\n' "$daede_revision" "$daede_revision" "$daed_source_revision" > package/custom/daede/.source-revision
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

echo "==> daed package source: $daede_revision"
echo "==> Argon theme source: $argon_revision"
echo "==> Go toolchain source: $golang_revision"
