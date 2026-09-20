#!/bin/sh
# Installs the app over SSH instead of USB. Usage: tools/install_ssh.sh <printer-ip>
# (root password: rockchip). The app then applies Turkish immediately.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${1:?usage: $0 <printer-ip>}
APP_NAME=20-turkish-ui
USER_APPS=/useremain/home/rinkhals/apps

python3 "$ROOT/tools/build_qm.py"
cp -f "$ROOT/dist/LanguageItaly.qm" "$ROOT/app/LanguageItaly.qm"

ssh root@$HOST "mkdir -p $USER_APPS/$APP_NAME"
scp -O -r "$ROOT/app/app.json" "$ROOT/app/app.sh" "$ROOT/app/patch_label.py" \
    "$ROOT/app/LanguageItaly.qm" root@$HOST:$USER_APPS/$APP_NAME/
ssh root@$HOST "chmod +x $USER_APPS/$APP_NAME/app.sh && touch $USER_APPS/$APP_NAME/.enabled && $USER_APPS/$APP_NAME/app.sh start && $USER_APPS/$APP_NAME/app.sh status"
echo "Done. On the printer: Settings > Language > Türkçe"
