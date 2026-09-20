# shellcheck source=../../../../../3-rinkhals/tools.sh
source /useremain/rinkhals/.current/tools.sh

APP_ROOT=$(dirname "$(realpath "$0")")
APP_NAME="20-turkish-ui"

GK_ROOT=/userdata/app/gk
TRANSLATE_DIR=$GK_ROOT/Translate
TARGET_QM=$TRANSLATE_DIR/LanguageItaly.qm
TURKISH_QM=$APP_ROOT/LanguageItaly.qm
# MD5 of the untouched Anycubic Italian file on KS1 firmware 2.7.2.7. Only the hash is
# shipped: Anycubic's own translation files are not redistributed with this app.
STOCK_QM_MD5=3b026b22c55f039e73868c1aab99b89a
MARKER=/tmp/rinkhals/turkish-ui.bootid

# State lives OUTSIDE the app directory: installing a newer SWU wipes the app directory
# (update.sh does "rm -rf $USER_APPS/$APP_NAME/*"), which would otherwise destroy the backup
# of the original Italian file and make us back up our own Turkish file on the next start.
STATE_DIR=$RINKHALS_HOME/turkish-ui
BACKUP_QM=$STATE_DIR/LanguageItaly.original.qm
INSTALLED_LIST=$STATE_DIR/installed-md5.txt

md5() { md5sum "$1" 2>/dev/null | awk '{print $1}'; }

turkish_installed() {
    [ "$(md5 $TARGET_QM)" = "$(md5 $TURKISH_QM)" ]
}

status() {
    if turkish_installed; then
        report_status $APP_STATUS_STARTED
    else
        report_status $APP_STATUS_STOPPED
    fi
}

# True if $1 is a file this app installed (any version of it)
is_our_qm() {
    [ -f $INSTALLED_LIST ] || return 1
    grep -q "^$(md5 $1)$" $INSTALLED_LIST 2> /dev/null
}

install_qm() {
    if [ ! -d $TRANSLATE_DIR ]; then
        log "/!\ $TRANSLATE_DIR not found, cannot install Turkish translation"
        return 1
    fi

    mkdir -p $STATE_DIR

    # Migrate the backup from the old in-app location, if it is still there
    if [ ! -f $BACKUP_QM ] && [ -f $APP_ROOT/backup/LanguageItaly.qm ]; then
        cp -f $APP_ROOT/backup/LanguageItaly.qm $BACKUP_QM
        log "Migrated original translation backup to $BACKUP_QM"
    fi

    # Remember every Turkish file we ship, so an upgrade never mistakes our own
    # output for the original Italian file
    touch $INSTALLED_LIST
    OUR_MD5=$(md5 $TURKISH_QM)
    grep -q "^$OUR_MD5$" $INSTALLED_LIST 2> /dev/null || echo $OUR_MD5 >> $INSTALLED_LIST

    if turkish_installed; then
        log "Turkish translation already installed"
        return 0
    fi

    # Keep the file we are replacing so stop() can restore it, but only when it really is
    # the stock Italian file. Anything else is either our own output (an upgrade) or an
    # unknown firmware's file, and capturing it would make stop() restore the wrong text.
    if [ ! -f $BACKUP_QM ] && [ -f $TARGET_QM ] && ! is_our_qm $TARGET_QM; then
        if [ "$(md5 $TARGET_QM)" = "$STOCK_QM_MD5" ]; then
            cp -f $TARGET_QM $BACKUP_QM
            log "Backed up the original translation to $BACKUP_QM"
        else
            log "Existing translation is neither stock nor ours, not backing it up"
        fi
    fi

    cp -f $TURKISH_QM $TARGET_QM
    chmod 644 $TARGET_QM
    log "Installed Turkish translation as $TARGET_QM"
}

restore_qm() {
    if ! turkish_installed; then
        return 0
    fi

    if [ ! -f $BACKUP_QM ]; then
        log "/!\ No backup of the original translation, leaving $TARGET_QM as is"
        log "    (a firmware update will restore Anycubic's own file)"
        return 1
    fi

    cp -f $BACKUP_QM $TARGET_QM
    chmod 644 $TARGET_QM
    log "Restored Italian translation to $TARGET_QM"
}

# Re-launch K3SysUi from a copy carrying the Rinkhals patch (if any) plus the label patch.
# Mirrors the "little dance" in Rinkhals start.sh: the copy is moved away after startup so
# the stock binary on disk stays untouched.
restart_ui_with_label() {
    if [ ! -f $GK_ROOT/K3SysUi ]; then
        log "/!\ $GK_ROOT/K3SysUi not found, skipping label patch"
        return 1
    fi

    log "Restarting K3SysUi with the 'Türkçe' label patch"

    cd $GK_ROOT || return 1
    kill_by_name K3SysUi

    rm -rf K3SysUi.original 2> /dev/null
    mv K3SysUi K3SysUi.original
    cp K3SysUi.original K3SysUi

    RINKHALS_PATCH=$RINKHALS_ROOT/opt/rinkhals/patches/K3SysUi.${KOBRA_MODEL_CODE}_${KOBRA_VERSION}.sh
    if [ -f $RINKHALS_PATCH ]; then
        $RINKHALS_PATCH K3SysUi > /dev/null 2>&1
    fi
    python $APP_ROOT/patch_label.py K3SysUi >> $RINKHALS_LOGS/app-turkish-ui.log 2>&1
    chmod +x K3SysUi

    USE_MUTABLE_CONFIG=1 LD_LIBRARY_PATH=$GK_ROOT:$LD_LIBRARY_PATH ./K3SysUi >> $RINKHALS_LOGS/K3SysUi.log 2>&1 &

    sleep 2

    rm -rf K3SysUi.patch 2> /dev/null
    mv K3SysUi K3SysUi.patch
    mv K3SysUi.original K3SysUi

    cat /tmp/rinkhals/bootid > $MARKER 2> /dev/null
}

start() {
    install_qm || return 1

    PATCH_LABEL=$(get_app_property $APP_NAME patch_label)
    if [ "$PATCH_LABEL" = "True" ]; then
        # Only once per boot: K3SysUi keeps running with the patched label afterwards
        if [ -f $MARKER ] && [ "$(cat $MARKER)" = "$(cat /tmp/rinkhals/bootid 2>/dev/null)" ]; then
            log "K3SysUi already patched this boot, skipping restart"
        else
            restart_ui_with_label
        fi
    fi
}

stop() {
    restore_qm
    log "Turkish translation removed (Italian is back after the next reboot)"
}

case "$1" in
    status)
        status
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo "Usage: $0 {status|start|stop}" >&2
        exit 1
        ;;
esac
