#!/usr/bin/env python3
"""
Unicorn Rocking Horse controller
Raspberry Pi 3 Model A+ — Final build

Behaviour:
  - Tilt the horse    -> plays random whinny + shows random photo
  - Press tail button -> plays random quote  + shows random photo
  - During any event, all other events are blocked until it finishes

Folder layout:
  /home/pi/whinnies/    -- .wav horse whinny files
  /home/pi/quotes/      -- .wav funny quote files
  /home/pi/pictures/    -- .jpg or .png photos
"""

import os
import sys
import glob
import time
import math
import random
import subprocess

import smbus2
from gpiozero import Button
from PIL import Image

# Waveshare library -- must be in the same folder as this script
sys.path.append('/home/pi')
import LCD_2inch4


# ---------------------------------------------------------
# SETTINGS
# ---------------------------------------------------------

WHINNY_FOLDER  = "/home/pi/whinnies"
QUOTE_FOLDER   = "/home/pi/quotes"
PICTURE_FOLDER = "/home/pi/pictures"

BUTTON_PIN    = 5     # Grove D5 slot on the HAT
TILT_DEGREES  = 25    # tilt angle that triggers a whinny
TILT_COOLDOWN = 3     # seconds before another tilt whinny can fire

# LIS3DHTR I2C address
LIS3DH_ADDR   = 0x19


# ---------------------------------------------------------
# GLOBAL STATE
# ---------------------------------------------------------

busy        = False   # True while an event is running
button_flag = False   # set by button thread, read by main loop


# ---------------------------------------------------------
# ACCELEROMETER -- LIS3DHTR via I2C
# ---------------------------------------------------------

def init_accelerometer():
    bus = smbus2.SMBus(1)
    # CTRL_REG1: 10Hz data rate, normal mode, all axes enabled
    bus.write_byte_data(LIS3DH_ADDR, 0x20, 0x27)
    time.sleep(0.1)
    return bus


def read_accel(bus):
    """Return (x, y, z) as signed 16-bit integers, or None if not ready."""
    status = bus.read_byte_data(LIS3DH_ADDR, 0x27)
    if not (status & 0x08):
        return None  # data not ready yet

    raw = bus.read_i2c_block_data(LIS3DH_ADDR, 0x28 | 0x80, 6)

    x = (raw[1] << 8) | raw[0]
    y = (raw[3] << 8) | raw[2]
    z = (raw[5] << 8) | raw[4]

    x = x - 65536 if x > 32767 else x
    y = y - 65536 if y > 32767 else y
    z = z - 65536 if z > 32767 else z

    return (x, y, z)


def angle_between(v1, v2):
    """Angle in degrees between two 3-D vectors."""
    dot  = sum(a * b for a, b in zip(v1, v2))
    mag1 = math.sqrt(sum(a * a for a in v1))
    mag2 = math.sqrt(sum(b * b for b in v2))
    if mag1 == 0 or mag2 == 0:
        return 0.0
    return math.degrees(math.acos(max(-1.0, min(1.0, dot / (mag1 * mag2)))))


# ---------------------------------------------------------
# DISPLAY -- Waveshare 2.4" LCD
# ---------------------------------------------------------

def init_display():
    """Initialise and return the Waveshare LCD object."""
    display = LCD_2inch4.LCD_2inch4()
    display.Init()
    display.clear()
    return display


def show_image(display, path):
    """Load an image, resize to screen, and show it."""
    img = Image.open(path)
    img = img.resize((240, 320), Image.LANCZOS)
    img = img.convert("RGB")
    display.ShowImage(img)


# ---------------------------------------------------------
# SOUND FILES
# ---------------------------------------------------------

WHINNIES = glob.glob(os.path.join(WHINNY_FOLDER,  "*.wav"))
QUOTES   = glob.glob(os.path.join(QUOTE_FOLDER,   "*.wav"))
PICTURES = (glob.glob(os.path.join(PICTURE_FOLDER, "*.jpg")) +
            glob.glob(os.path.join(PICTURE_FOLDER, "*.png")))

# Warn if MP3 files are present but no WAV files found
def _warn_if_mp3_only(folder, wav_list, label):
    if not wav_list:
        mp3s = glob.glob(os.path.join(folder, "*.mp3"))
        if mp3s:
            print(f"WARNING: {label} folder contains MP3 files but only WAV files are supported.")
            print(f"  Found: {', '.join(os.path.basename(f) for f in mp3s)}")
            print(f"  Please convert them to WAV. Example:")
            print(f"    sudo apt-get install ffmpeg")
            print(f"    for f in {folder}/*.mp3; do ffmpeg -i \"$f\" \"${{f%.mp3}}.wav\"; done")

_warn_if_mp3_only(WHINNY_FOLDER,  WHINNIES, "whinnies")
_warn_if_mp3_only(QUOTE_FOLDER,   QUOTES,   "quotes")


# ---------------------------------------------------------
# EVENTS -- both block until fully complete
# ---------------------------------------------------------

def play_whinny(display):
    global busy
    busy = True
    try:
        if not WHINNIES:
            print("No whinny files found in", WHINNY_FOLDER)
            return

        sound   = random.choice(WHINNIES)
        picture = random.choice(PICTURES) if PICTURES else None

        print("Whinny:", os.path.basename(sound))
        proc = subprocess.Popen(["aplay", "-D", "default", sound])

        if picture:
            print("Showing:", os.path.basename(picture))
            try:
                show_image(display, picture)
            except Exception as e:
                print("Image error:", e)

        proc.wait()

    finally:
        busy = False


def play_quote(display):
    global busy
    busy = True
    try:
        if not QUOTES:
            print("No quote files found in", QUOTE_FOLDER)
            return

        sound   = random.choice(QUOTES)
        picture = random.choice(PICTURES) if PICTURES else None

        print("Quote:", os.path.basename(sound))
        proc = subprocess.Popen(["aplay", "-D", "default", sound])

        if picture:
            print("Showing:", os.path.basename(picture))
            try:
                show_image(display, picture)
            except Exception as e:
                print("Image error:", e)

        proc.wait()

    finally:
        busy = False


# ---------------------------------------------------------
# BUTTON CALLBACKS
# Run in gpiozero background thread.
# Only set flags -- never touch display or audio directly.
# ---------------------------------------------------------

def on_button_pressed():
    global button_flag
    if not busy:
        button_flag = True


# ---------------------------------------------------------
# MAIN
# ---------------------------------------------------------

def main():
    global button_flag

    print("Initialising display...")
    display = init_display()

    print("Initialising accelerometer...")
    bus = init_accelerometer()

    # Yellow wire -> GPIO5, Black wire -> GND
    # Red and White wires must be left dangling and taped off
    button = Button(BUTTON_PIN, pull_up=True, bounce_time=0.1)
    button.when_pressed = on_button_pressed

    print("Calibrating - keep the horse still...")
    time.sleep(1.0)
    resting = None
    while resting is None:
        resting = read_accel(bus)
        time.sleep(0.05)
    print(f"Resting position: {resting}")

    if PICTURES:
        try:
            show_image(display, random.choice(PICTURES))
        except Exception as e:
            print("Startup image error:", e)

    print("Ready. Rock the horse or press the tail button.")

    last_tilt_time = 0.0

    try:
        while True:
            if button_flag and not busy:
                button_flag = False
                play_quote(display)

            if not busy:
                reading = read_accel(bus)
                if reading is not None:
                    tilt = angle_between(resting, reading)
                    now  = time.time()
                    if tilt > TILT_DEGREES and (now - last_tilt_time) > TILT_COOLDOWN:
                        last_tilt_time = now
                        play_whinny(display)

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\nStopped.")

    finally:
        display.clear()
        display.module_exit()


if __name__ == "__main__":
    main()
