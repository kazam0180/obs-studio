#!/usr/bin/env zsh

builtin emulate -L zsh
setopt EXTENDED_GLOB
setopt PUSHD_SILENT
setopt ERR_EXIT
setopt ERR_RETURN
setopt NO_UNSET
setopt PIPE_FAIL
setopt NO_AUTO_PUSHD
setopt NO_PUSHD_IGNORE_DUPS
setopt FUNCTION_ARGZERO

## Enable for script debugging
#setopt WARN_CREATE_GLOBAL
#setopt WARN_NESTED_VAR
#setopt XTRACE

typeset -g SCRIPT_HOME=${ZSH_ARGZERO:A:h}
fpath=(${SCRIPT_HOME}/utils.zsh ${fpath})
autoload -Uz log_group log_error log_status

typeset -r arch=$(uname -m)

pacman_retry() {
	local -i n=0
	while ! pacman "$@"; do
		n=$(( n + 1 ))
		(( n < 3 )) || return 1
		sleep 5
	done
}

log_group 'Installing package dependencies...'
pacman_retry -Syu --noconfirm \
	asio                 \
	alsa-lib             \
	at-spi2-core         \
	base-devel           \
	ccache               \
	cmake                \
	cmocka               \
	curl                 \
	extra-cmake-modules  \
	ffmpeg               \
	fontconfig           \
	freetype2            \
	git                  \
	glib2                \
	jack2                \
	jansson              \
	jq                   \
	libdrm               \
	libfdk-aac           \
	libglvnd             \
	libpulse             \
	librist              \
	libva                \
	libvlc               \
	libvpl               \
	libx11               \
	libxcb               \
	libxcomposite        \
	libxdamage           \
	libxfixes            \
	libxinerama          \
	libxkbcommon         \
	libxrandr            \
	libxss               \
	libxtst              \
	luajit               \
	mbedtls3             \
	mesa                 \
	ninja                \
	nlohmann-json        \
	pciutils             \
	pipewire             \
	python               \
	qrcodegencpp-cmake   \
	qt6-base             \
	qt6-svg              \
	qt6-wayland          \
	simde                \
	sndio                \
	speexdsp             \
	srt                  \
	sudo                 \
	swig                 \
	systemd              \
	uthash               \
	v4l-utils            \
	wayland              \
	websocketpp          \
	wget                 \
	x264                 \
	xz                   \
	zsh

log_group 'Installing debloated packages...'
if [[ ${arch} == x86_64 ]]; then
	get-debloated-pkgs --add-common --prefer-nano intel-media-driver-mini
else
	get-debloated-pkgs --add-common --prefer-nano
fi

log_group 'Building nv-codec-headers...'
git clone --depth 1 --branch n13.1.15.0 https://github.com/FFmpeg/nv-codec-headers.git /tmp/nv-codec-headers
make -C /tmp/nv-codec-headers
sudo make -C /tmp/nv-codec-headers install PREFIX=/usr

log_group 'Setting up pre-built Chromium Embedded Framework...'
mkdir -p .deps
pushd .deps

IFS=';' read -r cef_version cef_baseurl cef_label cef_hash cef_revision <<EOF
$(jq -r --arg target "ubuntu-${arch}" '
	.configurePresets[]
	| select(.name=="dependencies")
	| .vendor["obsproject.com/obs-studio"].dependencies["cef"]
	| {version, baseUrl, "label", "hash": .hashes[$target], "revision": .revision[$target]}
	| join(";")
' ../CMakePresets.json)
EOF

if [[ -z ${cef_version} || -z ${cef_hash} ]]; then
	log_error 'Failed to read CEF specification from CMakePresets.json'
	exit 1
fi

typeset cef_dirname="cef_binary_${cef_version}_linux_${arch}${cef_revision:+_v${cef_revision}}"
curl --show-error --silent --location -O "${cef_baseurl}/${cef_dirname}.tar.xz"
echo "${cef_hash}  ${cef_dirname}.tar.xz" | sha256sum -c -
mkdir -p "${cef_dirname}"
XZ_OPT=-T0 tar --strip-components 1 -xJf "${cef_dirname}.tar.xz" -C "${cef_dirname}"
popd

log_group 'Fetching upstream version tags...'
git fetch --tags https://github.com/obsproject/obs-studio.git

log_group 'Building the application...'
cmake --preset ubuntu-ci \
	-DENABLE_BROWSER:BOOL=ON \
	-DCEF_ROOT_DIR:PATH="$PWD/.deps/${cef_dirname}" \
	-DCMAKE_INSTALL_LIBDIR:STRING=lib \
	-DMbedTLS_DIR:PATH=/usr/lib/mbedtls3/cmake/MbedTLS
cmake --build build_ubuntu -j"$(nproc)"
sudo cmake --install build_ubuntu --prefix /usr

if git describe --tags --exact-match >/dev/null 2>&1; then
	git describe --tags --exact-match > ~/version
else
	git describe --tags --always --dirty > ~/version
fi
