# Unicorn Rocking Horse — Software Setup Guide

Interactive Raspberry Pi 3 Model A+ rocking horse with sound, display, and motion detection.
The horse plays a whinny sound when rocked, or a funny quote when you press the tail button.

---

## ⚠️ Important: Write-Protected Filesystem

The Pi runs in **write-protected mode** to prevent SD card corruption if power is lost.
When protection is **ON**, changes don't persist after reboot unless you disable it first.

**Check the current status:**
```bash
cat /proc/cmdline | grep -o "overlay" || echo "Write protection is OFF"
```

**To make permanent changes:** disable write protection in `sudo raspi-config` (Performance Options → Overlay FS), make your changes, then re-enable it.

---

## Accessing the Pi

Throughout setup, you'll need to access the Pi remotely. You can use either:
- **SSH command line:** `ssh pi@<hostname>` from your computer's terminal
- **SSH browser/graphical file manager:** [MobaXTerm](https://mobaxterm.mobaxy.com/) (easier for file transfers)

Both methods work equally well — choose whichever you prefer.

**Important:** The Pi only connects to Wi-Fi networks that were configured during the Raspberry Pi Imager flashing step. If you want to use the Pi in a different location (different Wi-Fi), you'll need to flash the microSD card again with the new Wi-Fi credentials.

---

## Quick Start

### 1. Flash the microSD card

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to flash **Raspberry Pi OS Lite (32-bit or 64-bit)**.
In the Imager's advanced settings: set hostname, username (`pi`), password, and Wi-Fi credentials. Enable SSH.

### 2. Download and install

After the Pi boots, connect to it via SSH and run the installer:

```bash
wget https://github.com/michieljmmaas/JJCHedonHobbelpaart/releases/latest/download/rocking-horse.zip
unzip rocking-horse.zip
sudo bash install.sh
sudo reboot
```

---

## After you reboot

### 3a. Upload your own photos (optional)

Audio and photos are pre-loaded, but you can replace them. Use SCP or your SSH browser's file manager to upload photos to `~/pictures/`.

Supported formats: `.jpg` / `.png` (the display is landscape-oriented; portrait pictures will appear slightly squashed).

### 3b. Test it

Stop the service and run the script manually to verify everything works:

```bash
sudo systemctl stop rocking-horse
python3 ~/rocking_horse.py
```

You should see "Initialising display..." → "Calibrating..." → "Ready." with a photo on screen.

- Rock the horse past 25° → whinny plays, photo changes
- Press tail button → quote plays, photo changes

Watch the autostart log to confirm it runs on reboot:
```bash
journalctl -u rocking-horse -f
```

### 3c. Enable write protection (final safety step)

Once everything is working, enable write-protected mode to prevent SD card corruption if power is lost:

```bash
sudo raspi-config
```

Navigate to **Performance Options** → **Overlay FS** and select **Yes**. When asked about write-protecting the boot partition, select **No**. Reboot.

**Important:** With write protection enabled, filesystem changes don't persist after reboot. If you need to make permanent changes later, disable write protection first in `raspi-config`, make your changes, then re-enable it.

---

## Attaching & Detaching

### To attach the horse to the enclosure:
1. Insert the conversion cable into the Grove plug on the D5 slot
2. Connect the Dupont housing ends to the button cable
3. Plug in the speaker via the 3.5mm jack
4. Connect the powerbank via micro-USB

### To detach (for transport):
1. Remove the conversion cable ends from the Dupont housing → button disconnects
2. Pull the 3.5mm speaker plug
3. Unplug the micro-USB power
   
---

## Files in this package

```
rocking_horse.py              Main script — sensor input, audio, display
install.sh                    One-time setup (run once)
systemd/
  rocking-horse.service       Autostart on boot
README.md                     This file (software setup)
rocking_horse_build_plan.html Hardware details, wiring, assembly
```

For **hardware assembly, component list, and detailed wiring**, see `rocking_horse_build_plan.html`.

---

## Content Disclaimer

The quotes in the `quotes/` folder were recorded as student humor and are extracted from their original context purely for comedic effect. **They are not meant to be taken seriously, and the authors of this project do not condone or endorse the statements made in these recordings.** We were students and we were drunk. Please don't get the wrong idea about this one.

**Note:** Waveshare is not affiliated with this project, this disclaimer, or the content of the quotes. Waveshare is only providing the LCD display library as a third-party component.


---

## License

The code in this repository is released under the MIT License — do whatever you like with it. See [LICENSE](LICENSE) for the full text.

The install script downloads a third-party component that has its own terms:

| Component | License |
|-----------|---------|
| Waveshare 2.4" LCD Module (LCD_2inch4) | See documentation at [Waveshare Wiki](https://www.waveshare.com/wiki/2.4inch_LCD_Module) |
