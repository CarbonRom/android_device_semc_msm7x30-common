#!/sbin/busybox sh
# Copyright (C) 2011-2013 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set +x
_PATH="$PATH"
export PATH=/sbin
export BB=/sbin/busybox

cd /
$BB date >>boot.txt
exec >>boot.txt 2>&1
$BB rm /init

# create directories & mount filesystems
$BB mount -o remount,rw rootfs /

$BB mkdir -p /sys /tmp /proc /data /dev /system/bin /cache
$BB mount -t sysfs sysfs /sys
$BB mount -t proc proc /proc
$BB mkdir /dev/input /dev/graphics /dev/block /dev/log

# create device nodes
$BB mknod -m 666 /dev/null c 1 3
$BB mknod -m 666 /dev/graphics/fb0 c 29 0
$BB mknod -m 666 /dev/tty0 c 4 0
$BB mknod -m 600 /dev/block/mmcblk0 b 179 0
$BB mknod -m 666 /dev/log/system c 10 19
$BB mknod -m 666 /dev/log/radio c 10 20
$BB mknod -m 666 /dev/log/events c 10 21
$BB mknod -m 666 /dev/log/main c 10 22
$BB mknod -m 666 /dev/ashmem c 10 37
$BB mknod -m 666 /dev/urandom c 1 9
for i in 0 1 2 3 4 5 6 7 8 9
do
num=`$BB expr 64 + $i`
$BB mknod -m 600 /dev/input/event${i} c 13 $num
done
$BB mknod -m 600 /dev/block/mtdblock2 b 31 2

# leds & backlight configuration
BOOTREC_LED_RED="/sys/class/leds/red/brightness"
BOOTREC_LED_GREEN="/sys/class/leds/green/brightness"
BOOTREC_LED_BLUE="/sys/class/leds/blue/brightness"
BOOTREC_LED_BUTTONS_RGB1="/sys/class/leds/button-backlight-rgb1/brightness"
BOOTREC_LED_BUTTONS_RGB2="/sys/class/leds/button-backlight-rgb2/brightness"

keypad_input='2'
for input in `$BB ls -d /sys/class/input/input*`
do
type=`$BB cat ${input}/name`
case "$type" in
    (*keypad*) keypad_input=`$BB echo $input | $BB sed 's/^.*input//'`;;
    (*)        ;;
    esac
done

# trigger amber LED & button-backlight
busybox echo 30 > /sys/class/timed_output/vibrator/enable
busybox echo 255 > ${BOOTREC_LED_RED}
busybox echo 0 > ${BOOTREC_LED_GREEN}
busybox echo 255 > ${BOOTREC_LED_BLUE}
busybox echo 255 > ${BOOTREC_LED_BUTTONS_RGB1}
busybox echo 255 > ${BOOTREC_LED_BUTTONS_RGB2}

# keycheck
$BB cat /dev/input/event${keypad_input} > /dev/keycheck & KCPID=${!}
$BB sleep 3
$BB echo 30 > /sys/class/timed_output/vibrator/enable

# kill the keycheck process
$BB kill -9 ${KCPID}

# mount cache
$BB mount -t yaffs2 /dev/block/mtdblock2 /cache
$BB mount -o remount,rw /cache


# android ramdisk
load_image=/sbin/ramdisk.cpio

# boot decision
if [ -s /dev/keycheck -o -e /cache/recovery/boot ]
then
$BB echo 'RECOVERY BOOT' >>boot.txt
$BB rm -fr /cache/recovery/boot
# trigger blue led
$BB echo 0 > ${BOOTREC_LED_RED}
$BB echo 0 > ${BOOTREC_LED_GREEN}
$BB echo 255 > ${BOOTREC_LED_BLUE}
$BB echo 0 > ${BOOTREC_LED_BUTTONS_RGB1}
$BB echo 0 > ${BOOTREC_LED_BUTTONS_RGB2}
# framebuffer fix
$BB echo 0 > /sys/module/msm_fb/parameters/align_buffer
# recovery ramdisk
load_image=/sbin/ramdisk-recovery.cpio
else
$BB echo 'ANDROID BOOT' >>boot.txt
# poweroff LED & button-backlight
$BB echo 0 > ${BOOTREC_LED_RED}
$BB echo 0 > ${BOOTREC_LED_GREEN}
$BB echo 0 > ${BOOTREC_LED_BLUE}
$BB echo 0 > ${BOOTREC_LED_BUTTONS_RGB1}
$BB echo 0 > ${BOOTREC_LED_BUTTONS_RGB2}
# framebuffer fix
$BB echo 1 > /sys/module/msm_fb/parameters/align_buffer
fi

# unpack the ramdisk image
$BB cpio -i < ${load_image}

#remove ramdisk to save RAM
$BB rm -f /sbin/ramdisk*.cpio

# Create a symlink in /sbin for each command kernel busybox knows
for sym in $($BB --list | $BB grep -v '^su$'); do
# Don't overwrite existing files not to mess up recoveries
if [ ! -e "/sbin/$sym" ]; then
$BB ln -sf "$BB" "/sbin/$sym"
fi
done

$BB umount /cache
$BB umount /proc
$BB umount /sys

$BB rm -fr /dev/*
$BB date >>boot.txt
export PATH="${_PATH}"
exec /init
