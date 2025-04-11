# Steam Dynamic Compatdata Bind Mount using pam_namespace

This project provides configuration and a script (`steamlibrary.init`) for `pam_namespace.so` to automatically manage Steam's `compatdata` directories, addressing critical issues on **multi-user Linux systems utilizing shared Steam library folders**.

*(Tested on Debian 13 (Trixie/Testing). May require adjustments for other distributions.)*

## Problem Solved

On Linux systems where multiple users share a common Steam library folder (e.g., on a separate drive), two main problems arise with Steam Play / Proton `compatdata` directories:

1.  **Shared `compatdata` Directory & Conflicts:** Steam places the `compatdata` folder (containing Proton prefixes) *inside the shared library's* `steamapps` directory. When different users run games from this shared library, they all attempt to use the **exact same** prefix directories, leading to conflicts, corrupted prefixes, and overwritten settings/saves.
2.  **Incorrect File Ownership:** As multiple users interact with the *same* files in the shared `compatdata` location, file ownership often becomes incorrect for the current user. Proton may then encounter permission errors, causing games to fail to launch.

*(**Note on NTFS:** While this solution focuses on typical Linux filesystems, it *might* help with ownership issues on shared NTFS partitions, but this specific use case is untested.)*

## Solution

This setup uses `pam_namespace.so` to create an isolated mount namespace for each user session. Within this namespace:

1.  A configuration file (`99-steamlibrary.conf`) defines a dummy trigger and tells `pam_namespace.so` to execute a specific script (`steamlibrary.init`).
2.  The `steamlibrary.init` script runs upon login.
3.  It identifies the logging-in user (`$4`).
4.  It reads the user's `libraryfolders.vdf` to find Steam libraries.
5.  It filters out libraries located within the user's `$HOME`.
6.  For each remaining external/shared library, it **bind mounts** the user's private `$HOME/.steam/steam/steamapps/compatdata` directory onto the shared library's `steamapps/compatdata` location *within the namespace*.

This **redirects** all `compatdata` access in shared libraries to the user's **private home directory location**, solving both the conflict and ownership problems effectively and transparently for each user session.

## Prerequisites

* A Linux system using PAM. **Tested on Debian 13 (Trixie/Testing).** Adaptations may be needed for others.
* The `pam_namespace.so` module. (Often in `libpam-modules` on Debian/Ubuntu; check your distro). Most of the time it's already installed.
* `wget` installed (for quick setup).
* Root privileges for setup.

## Installation

You can use the Quick Setup script or follow the manual steps.

**A. Quick Setup Script (Recommended)**

1.  **Download the setup script:**
    ```bash
    wget -q --show-progress -O quick_setup.sh "https://raw.githubusercontent.com/thojo0/steam-multiuser-compatdata-fix/main/quick_setup.sh"
    chmod +x quick_setup.sh
    ```
2.  **Review the script:** Check the commands in `quick_setup.sh` to ensure they are appropriate for your system.
3.  **Run the script:**
    ```bash
    sudo bash quick_setup.sh
    ```
4.  **Reboot or Relogin:** Log out completely and log back in for the changes to take effect.
5.  **(Optional) Remove the script:**
    ```bash
    rm quick_setup.sh
    ```

**B. Manual Installation**

1.  **Download Configuration:**
    ```bash
    sudo wget -q --show-progress -O /etc/security/namespace.d/99-steamlibrary.conf "https://raw.githubusercontent.com/thojo0/steam-multiuser-compatdata-fix/main/steamlibrary.conf"
    ```

2.  **Download Script:**
    ```bash
    sudo wget -q --show-progress -O /etc/security/namespace.d/99-steamlibrary.init "https://raw.githubusercontent.com/thojo0/steam-multiuser-compatdata-fix/main/steamlibrary.init"
    ```

3.  **Make Script Executable:**
    ```bash
    sudo chmod 755 /etc/security/namespace.d/99-steamlibrary.init
    ```

4.  **Create Trigger Directory:**
    ```bash
    sudo mkdir -p /opt/pam_namespace_steamlibrarytrigger
    sudo chmod 755 /opt/pam_namespace_steamlibrarytrigger
    ```

5.  **Configure PAM:**
    Append the `pam_namespace.so` line to your PAM session configuration. I highly recommend trying `optional` first. If the mounts don't appear after relogin (check logs), change `optional` to `required`. Prioritized files for Debian-based systems are `/etc/pam.d/common-session` and `/etc/pam.d/common-session-noninteractive`.

    ```bash
    echo "session    optional    pam_namespace.so" | sudo tee -a "/etc/pam.d/common-session" "/etc/pam.d/common-session-noninteractive"
    ```
    **Critical Warning:** Incorrectly editing PAM files can prevent users (including yourself!) from logging in. Proceed with caution and ensure you have recovery access (e.g., a root password to sign in through console).

6.  **Reboot or Relogin:** Log out completely and log back in.

## Verification

After installation and full logout/login:

1.  **Check Mounts (within session):** In a user terminal:
    ```bash
    mount | grep compatdata
    ```
    Confirm lines show bind mounts from `~/.steam/steam/steamapps/compatdata` onto your shared library paths (e.g., `/shared/steamlib/steamapps/compatdata`).
2.  **Check Directory Content:** Compare contents:
    ```bash
    ls /path/to/shared/library/steamapps/compatdata
    ls ~/.steam/steam/steamapps/compatdata
    # Output should be identical.
    ```
3.  **Multi-User Test:** Log in as a *different* user who also uses the shared library. Launch a Proton game from the shared library. Verify it functions correctly and uses prefixes within *their own* home directory (`/home/otheruser/.steam/...`), not the first user's home or the shared path itself.

## Troubleshooting

* **Check System Logs:** View script logs using its tag:
    ```bash
    sudo journalctl -t steamlibrary.init
    # Or check general logs like /var/log/syslog, /var/log/auth.log
    ```
    Look for errors related to user/home detection, VDF parsing, directory checks, or mount commands.
* **File/Directory Permissions:** Ensure `/etc/security/namespace.d/99-steamlibrary.init` is `755`. Ensure `/opt/pam_namespace_steamlibrarytrigger` exists.
* **PAM Stack:** Double-check `pam_namespace.so` is in the correct PAM file(s) for your login method(s).
* **Paths:** Ensure `DUMMY_POLYDIR` in the script matches the `polydir` in `/etc/security/namespace.d/99-steamlibrary.conf`. Verify the user's VDF file (`~/.steam/steam/steamapps/libraryfolders.vdf`) exists and is readable by them.

## Disclaimer

This script modifies system configuration (PAM) and executes with root privileges during the sensitive login process. Incorrect setup or script errors could impact system stability or user login capabilities. **Use this script at your own risk.** Test thoroughly in your environment. Maintain recovery access to your system in case of issues. This solution is primarily intended for shared libraries on standard Linux filesystems; its effectiveness on NTFS is speculative and untested.
