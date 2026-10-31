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

export ARCH=${arch}
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export APPNAME=OBS_Studio
export DESKTOP=/usr/share/applications/com.obsproject.Studio.desktop
export ICON=/usr/share/icons/hicolor/256x256/apps/com.obsproject.Studio.png
export DEPLOY_LOCALE=1
export DEPLOY_OPENGL=1
export DEPLOY_PIPEWIRE=1
export DEPLOY_PYTHON=1
export PATH_MAPPING_HARDCODED='libobs.so*'

log_group 'Deploying dependencies...'
quick-sharun \
	/usr/bin/obs      \
	/usr/lib/libobs*  \
	/usr/lib/obs*

log_group 'Making AppImage...'
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in CI use --simple-test instead
log_group 'Testing AppImage...'
quick-sharun --test ./dist/*.AppImage
