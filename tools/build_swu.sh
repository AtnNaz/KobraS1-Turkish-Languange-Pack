#!/bin/sh
# Builds the installable SWU packages for the Kobra S1 (KS1):
#   dist/app-turkish-ui-ks1.swu      - installs the Rinkhals app (needs Rinkhals on the printer)
#   dist/turkish-ui-stock-ks1.swu         - stock firmware, no Rinkhals needed (patches files in place)
#   dist/turkish-ui-stock-revert-ks1.swu  - undoes update-stock.swu (restores Italian + stock K3SysUi)
# Copy the one you need to a FAT32 USB drive as aGVscF9zb3Nf/update.swu and plug it in.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME=20-turkish-ui
# KS1 / KS1M SWU password (from Rinkhals build/tools.sh)
SWU_PASSWORD='U2FsdGVkX1+lG6cHmshPLI/LaQr9cZCjA8HZt6Y8qmbB7riY'

# Stock K3SysUi 2.7.2.7: md5 before/after the label patch and the 3 "Italiano" slot offsets
STOCK_K3SYSUI_MD5=1bd84d3856b09a13a634143bb42378e5
PATCHED_K3SYSUI_MD5=43fe2095d285b314b2b5397d5d874cb0
LABEL_OFFSETS="3856968 3995000 4119912"

python3 "$ROOT/tools/build_qm.py"
cp -f "$ROOT/dist/LanguageItaly.qm" "$ROOT/app/LanguageItaly.qm"
mkdir -p "$ROOT/dist"

# pack <staging update_swu dir> <output swu>
pack() {
    DIR=$1; OUT=$2
    WORK=$(mktemp -d)
    ( cd "$DIR" && tar -cf "$WORK/setup.tar" --exclude='.DS_Store' . )
    mkdir "$WORK/update_swu"
    gzip -c "$WORK/setup.tar" > "$WORK/update_swu/setup.tar.gz"
    md5 -q "$WORK/update_swu/setup.tar.gz" > "$WORK/update_swu/setup.tar.gz.md5"
    rm -f "$OUT"
    ( cd "$WORK" && zip -0 -q -P "$SWU_PASSWORD" -r "$OUT" update_swu )
    rm -rf "$WORK"
    echo "built $OUT"
}

########## 1. Rinkhals app package ##########
STAGING=$(mktemp -d)
mkdir -p "$STAGING/$APP_NAME"
cp -r "$ROOT/app/." "$STAGING/$APP_NAME/"
rm -rf "$STAGING/$APP_NAME/backup"
cat > "$STAGING/update.sh" <<'UPDATE'
#!/bin/sh
# Installs the Türkçe Arayüz app into Rinkhals and reboots
SOURCE_PATH=/useremain/update_swu
USB_PATH=/mnt/udisk/aGVscF9zb3Nf
APP_NAME=20-turkish-ui
USER_APPS=/useremain/home/rinkhals/apps

log() {
    echo "$(date): ${*}" >> /useremain/rinkhals/install.log
    [ -e $USB_PATH ] && echo "$(date): ${*}" >> $USB_PATH/install-turkish-ui.log
}

if [ ! -e /useremain/rinkhals/.current ]; then
    log "Rinkhals is not installed, aborting (use turkish-ui-stock-ks1.swu instead)"
    exit 1
fi

# Older builds kept the backup of the original Italian file inside the app directory,
# which the wipe below would destroy. Migrate it to the persistent state directory first.
STATE_DIR=/useremain/home/rinkhals/turkish-ui
mkdir -p $STATE_DIR
if [ -f $USER_APPS/$APP_NAME/backup/LanguageItaly.qm ] && [ ! -f $STATE_DIR/LanguageItaly.original.qm ]; then
    cp -f $USER_APPS/$APP_NAME/backup/LanguageItaly.qm $STATE_DIR/LanguageItaly.original.qm
    log "Migrated the original translation backup to $STATE_DIR"
fi

mkdir -p $USER_APPS/$APP_NAME
rm -rf $USER_APPS/$APP_NAME/*
cp -r $SOURCE_PATH/$APP_NAME/* $USER_APPS/$APP_NAME/
chmod +x $USER_APPS/$APP_NAME/app.sh
touch $USER_APPS/$APP_NAME/.enabled
log "Installed and enabled $APP_NAME"

rm -rf $SOURCE_PATH
rm -f /useremain/update.swu
rm -f $USB_PATH/update.swu
sync
log "Rebooting"
reboot
UPDATE
chmod +x "$STAGING/update.sh"
pack "$STAGING" "$ROOT/dist/app-turkish-ui-ks1.swu"
rm -rf "$STAGING"

########## 2. Stock firmware package (no Rinkhals) ##########
STAGING=$(mktemp -d)
cp "$ROOT/app/LanguageItaly.qm" "$STAGING/LanguageItaly.qm"
# "Türkçe" + 4 NUL as octal escapes for busybox printf (12 bytes, same size as "Italiano" slot)
printf 'T\303\274rk\303\247e\000\000\000\000' > "$STAGING/label.bin"
cat > "$STAGING/update.sh" <<UPDATE
#!/bin/sh
# Türkçe Arayüz for stock Kobra S1 firmware: replaces the Italian translation file with
# Turkish and renames the "Italiano" menu entry to "Türkçe" in K3SysUi (backups kept).
SOURCE_PATH=/useremain/update_swu
USB_PATH=/mnt/udisk/aGVscF9zb3Nf
GK=/userdata/app/gk
LOG=/useremain/turkish-ui-install.log

STOCK_MD5=$STOCK_K3SYSUI_MD5
PATCHED_MD5=$PATCHED_K3SYSUI_MD5
OFFSETS="$LABEL_OFFSETS"

log() {
    echo "\$(date): \${*}" >> \$LOG
    [ -e \$USB_PATH ] && echo "\$(date): \${*}" >> \$USB_PATH/install-turkish-ui.log
}
finish() {
    rm -rf \$SOURCE_PATH
    rm -f /useremain/update.swu
    rm -f \$USB_PATH/update.swu
    sync
    log "Rebooting"
    reboot
}

log "Starting Türkçe Arayüz (stock) installation"

if [ -e /useremain/rinkhals/.current ]; then
    log "Rinkhals is installed, aborting: use app-turkish-ui-ks1.swu instead"
    finish
fi
if [ ! -d \$GK/Translate ] || [ ! -f \$GK/K3SysUi ]; then
    log "\$GK/Translate or K3SysUi not found, aborting"
    finish
fi

# 1. Translation file (keep the original Italian once)
[ -f \$GK/Translate/LanguageItaly.qm.stock ] || cp -f \$GK/Translate/LanguageItaly.qm \$GK/Translate/LanguageItaly.qm.stock
cp -f \$SOURCE_PATH/LanguageItaly.qm \$GK/Translate/LanguageItaly.qm.new
chmod 644 \$GK/Translate/LanguageItaly.qm.new
mv -f \$GK/Translate/LanguageItaly.qm.new \$GK/Translate/LanguageItaly.qm
log "Installed Turkish translation as LanguageItaly.qm"

# 2. Menu label (only for the exact K3SysUi build the offsets were computed for)
MD5=\$(md5sum \$GK/K3SysUi | awk '{print \$1}')
if [ "\$MD5" = "\$PATCHED_MD5" ]; then
    log "K3SysUi label already patched"
elif [ "\$MD5" = "\$STOCK_MD5" ]; then
    [ -f \$GK/K3SysUi.stock ] || cp -f \$GK/K3SysUi \$GK/K3SysUi.stock
    # The running binary cannot be written in place (text file busy): patch a copy, then rename over it
    cp -f \$GK/K3SysUi \$GK/K3SysUi.new
    for OFF in \$OFFSETS; do
        dd if=\$SOURCE_PATH/label.bin of=\$GK/K3SysUi.new bs=1 seek=\$OFF count=12 conv=notrunc 2> /dev/null
    done
    NEW_MD5=\$(md5sum \$GK/K3SysUi.new | awk '{print \$1}')
    if [ "\$NEW_MD5" = "\$PATCHED_MD5" ]; then
        chmod +x \$GK/K3SysUi.new
        mv -f \$GK/K3SysUi.new \$GK/K3SysUi
        log "K3SysUi label patched (Italiano -> Türkçe)"
    else
        rm -f \$GK/K3SysUi.new
        log "Patched K3SysUi md5 mismatch (\$NEW_MD5), label left unchanged"
    fi
else
    log "K3SysUi md5 \$MD5 is not the 2.7.2.7 build, label left unchanged (translation still installed)"
fi

log "Done: select Settings > Language > Türkçe after reboot"
finish
UPDATE
chmod +x "$STAGING/update.sh"
pack "$STAGING" "$ROOT/dist/turkish-ui-stock-ks1.swu"
rm -rf "$STAGING"

########## 3. Stock revert package ##########
STAGING=$(mktemp -d)
cat > "$STAGING/update.sh" <<'UPDATE'
#!/bin/sh
# Reverts update-stock.swu: restores the Italian translation and the stock K3SysUi from the backups
SOURCE_PATH=/useremain/update_swu
USB_PATH=/mnt/udisk/aGVscF9zb3Nf
GK=/userdata/app/gk
LOG=/useremain/turkish-ui-install.log

log() {
    echo "$(date): ${*}" >> $LOG
    [ -e $USB_PATH ] && echo "$(date): ${*}" >> $USB_PATH/install-turkish-ui.log
}

log "Reverting Türkçe Arayüz (stock)"
if [ -f $GK/Translate/LanguageItaly.qm.stock ]; then
    mv -f $GK/Translate/LanguageItaly.qm.stock $GK/Translate/LanguageItaly.qm
    log "Restored Italian translation"
else
    log "No LanguageItaly.qm.stock backup found"
fi
if [ -f $GK/K3SysUi.stock ]; then
    chmod +x $GK/K3SysUi.stock
    mv -f $GK/K3SysUi.stock $GK/K3SysUi
    log "Restored stock K3SysUi"
else
    log "No K3SysUi.stock backup found"
fi

rm -rf $SOURCE_PATH
rm -f /useremain/update.swu
rm -f $USB_PATH/update.swu
sync
log "Rebooting"
reboot
UPDATE
chmod +x "$STAGING/update.sh"
pack "$STAGING" "$ROOT/dist/turkish-ui-stock-revert-ks1.swu"
rm -rf "$STAGING"
