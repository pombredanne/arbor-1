#!/bin/bash
# Copyright 2010 Wulf C. Krueger <philantrop@exherbo.org>
# Distributed under the terms of the GNU General Public License v2
# Based in part upon 'checkroot'/'checkfs'/'bootmisc' from Gentoo, which is:
#     Copyright 1999-2007 Gentoo Foundation

retval=0

[[ -x /sbin/lvm ]] && lvm vgscan --mknodes

if touch -c / >& /dev/null ; then
    mount -n -o remount,ro /
fi

if [[ -f /forcefsck ]] || $(cat /proc/cmdline | grep -q "forcefsck") ; then
    fsck -C -a -f /
    retval=$?
else
    # Obey the fs_passno setting for / (see fstab(5))
    # - find the / entry
    # - make sure we have 6 fields
    # - see if fs_passno is something other than 0
    if [[ -n $(awk '($1 ~ /^(\/|UUID|LABEL)/ && $2 == "/" && NF == 6 && $6 != 0) { print }' /etc/fstab) ]]; then
        fsck -C -T -a /
        retval=$?
    else
        retval=0
    fi
fi

if [[ ${retval} -eq 2 || ${retval} -eq 3 ]] ; then
    echo "Filesystem repaired, but reboot needed!"
    echo -ne "\a"; sleep 1; echo -ne "\a"; sleep 1
    echo -ne "\a"; sleep 1; echo -ne "\a"; sleep 1
    echo "Rebooting in 10 seconds ..."
    sleep 10
    echo "Rebooting"
    /sbin/reboot -f
elif [[ ${retval} -gt 3 ]] ; then
    echo "Filesystem couldn't be fixed."
    sulogin
    echo "Unmounting filesystems"
    /bin/mount -a -o remount,ro &> /dev/null
    echo "Rebooting"
    /sbin/reboot -f
fi

if [[ -f /forcefsck ]] ; then
    ewarn "A full fsck has been forced"
    fsck -C -T -R -A -a -f
    retval=$?
    rm -f /forcefsck
else
    fsck -C -T -R -A -a
    retval=$?
fi
if [[ ${retval} -gt 3 ]] ; then
    echo "Fsck could not correct all errors, manual repair needed"
    sulogin
fi

# Should we mount root rw ?  the touch check is to see if the / is
# already mounted rw in which case there's nothing for us to do
if mount -vf -o remount / 2> /dev/null | \
   awk '{ if ($6 ~ /rw/) exit 0; else exit 1; }' && \
   ! touch -c / >& /dev/null
then
    mount -n -o remount,rw / &> /dev/null
    if [[ $? -ne 0 ]] ; then
        echo "Root filesystem could not be mounted read/write :("
        sulogin
    fi
fi

# Create /etc/mtab
# Clear the existing mtab
> /etc/mtab

# Add the entry for / to mtab
mount -f /

# Don't list root more than once
awk '$2 != "/" {print}' /proc/mounts >> /etc/mtab

# Now make sure /etc/mtab have additional info (gid, etc) in there
for x in $(awk '{ print $2 }' /proc/mounts | sort -u) ; do
    for y in $(awk '{ print $2 }' /etc/fstab) ; do
        if [[ ${x} == ${y} ]] ; then
            mount -f -o remount $x
            continue
        fi
    done
done

# Remove stale backups
rm -f /etc/mtab~ /etc/mtab~~

# Take care of random stuff [ /var/lock | /var/run | pam ]
rm -rf /var/run/console.lock /var/run/console/*

# Clean up any stale locks.
find /var/lock -type f -print0 | xargs -0 rm -f --

# Clean up /var/run and create /var/run/utmp so that we can login.
for x in $(find /var/run/ ! -type d ! -name utmp ! -name innd.pid ! -name random-seed) ; do
    daemon=${x##*/}
    daemon=${daemon%*.pid}
    # Do not remove pidfiles of already running daemons
    if [[ -z $(ps --no-heading -C "${daemon}") ]] ; then
        if [[ -f ${x} || -L ${x} ]] ; then
            rm -f "${x}"
        fi
    fi
done

# Create the .keep to stop the PM from removing /var/lock
> /var/lock/.keep

# Clean up /tmp directory
if [[ -d /tmp ]] ; then
    cd /tmp
    exceptions="
        '!' -name . -a
        '!' '(' -uid 0 -a
            '('
                -path './lost+found/*' -o
                -path './quota.user' -o
            -path './quota.user/*' -o
            -path './aquota.user/*' -o
            -path './quota.group/*' -o
            -path './aquota.group/*' -o
            -path './.journal/*'
        ')' -o '(' -type d -a
        '('
            -path './lost+found' -o
            -path './quota.user' -o
            -path './aquota.user' -o
            -path './quota.group' -o
            -path './aquota.group' -o
            -path './.journal'
        ')' ')'
    ')'"
    # First kill most files, then kill empty dirs
    eval find . -xdev -depth ${exceptions} ! -type d -print0 | xargs -0 rm -f --
    eval find . -xdev -depth ${exceptions}   -type d -empty -exec rmdir '{}' \\';'

    (
        # Make sure our X11 stuff have the correct permissions
        # Omit the chown as bootmisc is run before network is up
        # and users may be using lame LDAP auth #139411
        rm -rf /tmp/.{ICE,X11}-unix
        mkdir -p /tmp/.{ICE,X11}-unix
        #chown 0:0 /tmp/.{ICE,X11}-unix
        chmod 1777 /tmp/.{ICE,X11}-unix
        [[ -x /sbin/restorecon ]] && restorecon /tmp/.{ICE,X11}-unix
    ) &> /dev/null
fi

# Create an 'after-boot' dmesg log
touch /var/log/dmesg
chmod 640 /var/log/dmesg
dmesg > /var/log/dmesg

# Check for /etc/resolv.conf, and create if missing
[[ -f /etc/resolv.conf ]] || touch /etc/resolv.conf &> /dev/null

# vim:ts=4
