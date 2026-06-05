[ -z $BASH ] && { exec bash "$0" "$@" || exit; }

if [ "$(id -u)" != 0 ]; then
    echo 'Sorry, you need to run this script with sudo'
    exit 1
fi

if [ -z "$SUDO_USER" ] || ! id "$SUDO_USER" &>/dev/null; then
    echo 'Could not determine the target user.'
    echo 'Make sure you run this with sudo, e.g.: sudo bash install.sh'
    exit 1
fi

# ── External URLs ──────────────────────────────────────────────────────────────
URL_WAVESHARE_LCD="https://files.waveshare.com/upload/8/8d/LCD_Module_RPI_code.zip"

# ── Formatting helpers ─────────────────────────────────────────────────────────
BOLD='\033[1m'; DIM='\033[2m'
GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'

TOTAL_STEPS=10
CURRENT_STEP=0

LOG_FILE="/tmp/rocking_horse_install.log"
ERR=0

> "$LOG_FILE"

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    printf "\n${BOLD}${CYAN} [%d/%d]${RESET} ${BOLD}%s${RESET}\n" \
        "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
}

ok()   { printf "   ${GREEN}✓${RESET} %s\n" "$1"; }
skip() { printf "   ${DIM}– %s (skipped)${RESET}\n" "$1"; }

run_quiet() {
    local label="$1"; shift
    printf "   · %s" "$label"
    "$@" >>"$LOG_FILE" 2>&1 &
    local pid=$! i=0 sp='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r   %s %s " "${sp:$((i++ % 4)):1}" "$label"
        sleep 0.15
    done
    wait "$pid"; local rc=$?
    if [ $rc -eq 0 ]; then
        printf "\r   ${GREEN}✓${RESET} %s\033[K\n" "$label"
    else
        printf "\r   ${RED}✗${RESET} %s ${DIM}(see %s)${RESET}\033[K\n" "$label" "$LOG_FILE"
        ERR=$((ERR+1))
    fi
    return $rc
}

download() {
    local label="$1" url="$2" dest="$3"
    printf "   · %s" "$label"
    wget -q "$url" -O "$dest" >>"$LOG_FILE" 2>&1 &
    local pid=$! i=0 sp='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r   %s %s " "${sp:$((i++ % 4)):1}" "$label"
        sleep 0.15
    done
    wait "$pid"; local rc=$?
    if [ $rc -eq 0 ]; then
        printf "\r   ${GREEN}✓${RESET} %s\033[K\n" "$label"
    else
        printf "\r   ${RED}✗${RESET} %s ${DIM}(see %s)${RESET}\033[K\n" "$label" "$LOG_FILE"
        ERR=$((ERR+1))
    fi
    return $rc
}

# ── Config ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_HOME="/home/$SUDO_USER"

BOOT_CONFIG_FILE="/boot/firmware/config.txt"

# ── Header ─────────────────────────────────────────────────────────────────────
printf "\n${BOLD}"
printf "  ╔══════════════════════════════════════════════╗\n"
printf "  ║   Unicorn Rocking Horse — Installation      ║\n"
printf "  ╚══════════════════════════════════════════════╝\n"
printf "${RESET}  Log: ${DIM}%s${RESET}\n" "$LOG_FILE"

# ── [1/10] Enable I2C ──────────────────────────────────────────────────────────
step "Enable I2C"

grep -q 'i2c-bcm2708' /etc/modules \
    && skip "i2c-bcm2708 module" \
    || { echo 'i2c-bcm2708' >> /etc/modules && ok "Added i2c-bcm2708 module"; }

grep -q 'i2c-dev' /etc/modules \
    && skip "i2c-dev module" \
    || { echo 'i2c-dev' >> /etc/modules && ok "Added i2c-dev module"; }

i2c1=$(grep 'dtparam=i2c1=on' "$BOOT_CONFIG_FILE" | sed -e 's/^[[:space:]]*//')
if [[ -z "$i2c1" || "$i2c1" == "#"* ]]; then
    echo 'dtparam=i2c1=on' >> "$BOOT_CONFIG_FILE" && ok "Enabled dtparam=i2c1"
else skip "dtparam=i2c1"; fi

i2c_arm=$(grep 'dtparam=i2c_arm=on' "$BOOT_CONFIG_FILE" | sed -e 's/^[[:space:]]*//')
if [[ -z "$i2c_arm" || "$i2c_arm" == "#"* ]]; then
    echo 'dtparam=i2c_arm=on' >> "$BOOT_CONFIG_FILE" && ok "Enabled dtparam=i2c_arm"
else skip "dtparam=i2c_arm"; fi

if [ -f /etc/modprobe.d/raspi-blacklist.conf ]; then
    sed -i 's/^blacklist spi-bcm2708/#blacklist spi-bcm2708/' /etc/modprobe.d/raspi-blacklist.conf
    sed -i 's/^blacklist i2c-bcm2708/#blacklist i2c-bcm2708/' /etc/modprobe.d/raspi-blacklist.conf
    ok "Updated raspi-blacklist.conf"
else skip "raspi-blacklist.conf (not present)"; fi

# ── [2/10] Enable SPI ──────────────────────────────────────────────────────────
step "Enable SPI"

spi=$(grep 'dtparam=spi=on' "$BOOT_CONFIG_FILE" | sed -e 's/^[[:space:]]*//')
if [[ -z "$spi" || "$spi" == "#"* ]]; then
    echo 'dtparam=spi=on' >> "$BOOT_CONFIG_FILE" && ok "Enabled dtparam=spi"
else skip "dtparam=spi"; fi

# ── [3/10] System packages ─────────────────────────────────────────────────────
step "Install system packages"

run_quiet "apt-get update" apt-get update -q

run_quiet "Core packages" \
    apt-get install -y -q \
        i2c-tools \
        python3-pip \
        python3-smbus \
        python3-rpi.gpio \
        python3-spidev \
        alsa-utils \
        unzip

# ── [4/10] Python packages ─────────────────────────────────────────────────────
step "Install Python packages"

run_quiet "pip install pillow smbus2 gpiozero" \
    pip3 install -q pillow smbus2 gpiozero

# ── [5/10] ALSA audio config ───────────────────────────────────────────────────
step "Configure ALSA audio (headphone jack)"

ASOUNDRC="$USER_HOME/.asoundrc"
if [ -f "$ASOUNDRC" ]; then
    skip "~/.asoundrc (already exists)"
else
    cat > "$ASOUNDRC" << 'EOF'
pcm.!default {
    type hw
    card 0
    device 0
}
ctl.!default {
    type hw
    card 0
}
EOF
    chown "$SUDO_USER:$(id -g -n $SUDO_USER)" "$ASOUNDRC"
    ok "~/.asoundrc written (forces headphone jack output)"
fi

# Also set headphone jack via amixer if possible
amixer -c 0 cset numid=3 1 >>"$LOG_FILE" 2>&1 && ok "amixer: audio routed to headphone jack" \
    || skip "amixer routing (run 'amixer -c 0 cset numid=3 1' manually if audio is silent)"

# ── [6/10] Waveshare 2.4" LCD library ─────────────────────────────────────────
step "Install Waveshare 2.4\" LCD library"

if [ -f "$USER_HOME/LCD_2inch4.py" ] && [ -f "$USER_HOME/lcdconfig.py" ]; then
    skip "Waveshare LCD library (files already present)"
else
    TMP_ZIP="/tmp/LCD_Module_RPI_code.zip"
    TMP_DIR="/tmp/waveshare_lcd"

    download "Waveshare LCD library" "$URL_WAVESHARE_LCD" "$TMP_ZIP" && {
        run_quiet "Unpack library" unzip -q "$TMP_ZIP" -d "$TMP_DIR"

        LIB_DIR=$(find "$TMP_DIR" -path "*/RaspberryPi/python/lib" -type d | head -1)
        if [ -z "$LIB_DIR" ]; then
            printf "   ${RED}✗${RESET} Could not find lib folder inside zip\n"
            ERR=$((ERR+1))
        else
            cp "$LIB_DIR/lcdconfig.py"  "$USER_HOME/" || ERR=$((ERR+1))
            cp "$LIB_DIR/LCD_2inch4.py" "$USER_HOME/" || ERR=$((ERR+1))

            # Fix import so it works when called from /home/pi directly
            sed -i 's/from \. import lcdconfig/import lcdconfig/' "$USER_HOME/LCD_2inch4.py" \
                >>"$LOG_FILE" 2>&1

            chown "$SUDO_USER:$(id -g -n $SUDO_USER)" \
                "$USER_HOME/lcdconfig.py" "$USER_HOME/LCD_2inch4.py"
            ok "LCD_2inch4.py and lcdconfig.py installed to $USER_HOME"
        fi

        rm -rf "$TMP_ZIP" "$TMP_DIR"
    }
fi

# ── [7/10] Install main script ─────────────────────────────────────────────────
step "Install rocking_horse.py"

if [ -f "$SCRIPT_DIR/rocking_horse.py" ]; then
    cp "$SCRIPT_DIR/rocking_horse.py" "$USER_HOME/rocking_horse.py"
    chown "$SUDO_USER:$(id -g -n $SUDO_USER)" "$USER_HOME/rocking_horse.py"
    chmod +x "$USER_HOME/rocking_horse.py"
    ok "rocking_horse.py installed to $USER_HOME"
else
    printf "   ${RED}✗${RESET} rocking_horse.py not found in $SCRIPT_DIR — copy it manually\n"
    ERR=$((ERR+1))
fi

# ── [8/10] systemd service ─────────────────────────────────────────────────────
step "Install systemd service (autostart on boot)"

SERVICE_SRC="$SCRIPT_DIR/systemd/rocking-horse.service"
SERVICE_DEST="/etc/systemd/system/rocking-horse.service"

if [ -f "$SERVICE_DEST" ]; then
    skip "rocking-horse.service (already installed)"
else
    if [ -f "$SERVICE_SRC" ]; then
        cp "$SERVICE_SRC" "$SERVICE_DEST"
    else
        # Write it inline as fallback
        cat > "$SERVICE_DEST" << EOF
[Unit]
Description=Unicorn Rocking Horse
After=network.target sound.target

[Service]
Type=simple
User=$SUDO_USER
WorkingDirectory=$USER_HOME
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/python3 $USER_HOME/rocking_horse.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    fi

    run_quiet "systemctl daemon-reload"       systemctl daemon-reload
    run_quiet "Enable rocking-horse service"  systemctl enable rocking-horse.service
    ok "Service enabled — will start automatically on boot"
fi

# ── [9/10] GPIO permission ────────────────────────────────────────────────────
step "Add $SUDO_USER to gpio / spi / i2c / audio groups"

for group in gpio spi i2c audio; do
    if getent group "$group" > /dev/null 2>&1; then
        usermod -aG "$group" "$SUDO_USER" && ok "Added to $group" || skip "$group"
    else
        skip "$group group (not present)"
    fi
done

# ── Summary ────────────────────────────────────────────────────────────────────
printf "\n${BOLD}${CYAN}  ══════════════════════════════════════════════${RESET}\n"
if [ $ERR -eq 0 ]; then
    printf "  ${GREEN}${BOLD}All done!${RESET} No errors.\n\n"
    printf "  Next steps:\n"
    printf "   1. sudo reboot\n"
    printf "   2. Verify audio and photo files are in place:\n"
    printf "        ls ~/whinnies/ ~/quotes/ ~/pictures/\n"
    printf "   3. Test manually:\n"
    printf "        python3 ~/rocking_horse.py\n"
    printf "   4. Check service status:\n"
    printf "        journalctl -u rocking-horse -f\n"
else
    printf "  ${RED}${BOLD}Finished with %d error(s).${RESET}\n" "$ERR"
    printf "  Full log: ${BOLD}%s${RESET}\n" "$LOG_FILE"
fi
printf "${BOLD}${CYAN}  ══════════════════════════════════════════════${RESET}\n\n"
