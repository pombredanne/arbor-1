#!/sbin/runscript
# Copyright 1999-2004 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/www/viewcvs.gentoo.org/raw_cvs/gentoo-x86/sys-apps/xinetd/files/xinetd.rc6,v 1.19 2005/07/30 07:34:26 vapier Exp $

opts="start stop reload restart dump check"

depend() {
    use net
}

start() {
    ebegin "Starting xinetd"
    (
    # workaround for #25754
    unset -f `declare -F | sed 's:declare -f::g'`
    /usr/sbin/xinetd -pidfile /run/xinetd.pid ${XINETD_OPTS}
    )
    eend $?
}

stop() {
    ebegin "Stopping xinetd"
    start-stop-daemon --stop --quiet --pidfile /run/xinetd.pid
    eend $?
}

reload(){
    ebegin "Reloading configuration"
    killall -HUP xinetd &>/dev/null
    eend $?
}

dump(){
    ebegin "Dumping configuration"
    killall -USR1 xinetd &>/dev/null
    eend $?
}

check(){
    ebegin "Performing Consistency Check"
    killall -IOT xinetd &>/dev/null
    eend $?
}
