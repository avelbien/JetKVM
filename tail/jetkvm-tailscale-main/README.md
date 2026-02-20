# JetKVM Tailscale Installer

This project provides automated scripts to install, configure, and maintain Tailscale on a JetKVM device. It supports both the official Tailscale control plane and self-hosted Headscale instances.

## Features

*   **Automated Installation**: Downloads the latest compatible ARM binary, transfers it to the device, and sets everything up.
*   **Persistence**: Includes a robust init script (`S22tailscale`) that ensures Tailscale starts automatically on boot, waiting for the network interface to be ready.
*   **Headscale Support**: Easily connect to your self-hosted Headscale server.
*   **Smart Updates**: Checks the installed version against the latest available version. Only downloads and transfers files if an update is needed.
*   **OS Update Recovery**: JetKVM OS updates often wipe the `/etc/init.d` directory. This script can quickly restore the init script and service without requiring re-authentication.
*   **Embedded-Friendly**: Uses SSH piping instead of SCP (which is missing on JetKVM) and places PID files in `/tmp` to ensure compatibility with the read-only/overlay filesystem nature of the device.

## Prerequisites

1.  **JetKVM Device**:
    *   Developer Mode must be enabled in the JetKVM web UI.
    *   Your SSH public key must be added to the device.
2.  **Host Machine**:
    *   Linux, macOS, or WSL.
    *   `bash`, `curl`, and `ssh` installed.

## Installation

1.  **Clone the repository** (or download the files):
    ```bash
    git clone git@github.com:thinktankmachine/jetkvm-tailscale.git
    cd jetkvm-tailscale
    ```

2.  **Configure the environment**:
    Copy the example configuration file and edit it with your details.
    ```bash
    cp .env.example .env
    nano .env
    ```
    *   `JETKVM_IP`: The IP address of your JetKVM.
    *   `SSH_USER`: Usually `root`.
    *   `TAILSCALE_LOGIN_SERVER`: Leave empty for official Tailscale, or set your Headscale URL (e.g., `https://hs.example.com`).
    *   `TAILSCALE_AUTH_KEY`: Your pre-authentication key.
    *   `TAILSCALE_VERSION`: (Optional) Specify a version (e.g., `1.90.9`) to install. If empty, the latest stable version is used.

3.  **Run the setup script**:
    ```bash
    ./setup.sh
    ```
    This will:
    *   Check for the latest Tailscale ARM version (or the one specified in `.env`).
    *   Download it if necessary.
    *   Transfer the binary and scripts to the JetKVM.
    *   Install the init script.
    *   Start the service and authenticate.

## Updating & Maintenance

### Updating Tailscale
To update the Tailscale binary to the latest version, simply run the setup script with the update flag:

```bash
./setup.sh --update
```
This will stop the service, update the binary, and restart it without changing your authentication status.

To install a specific version (e.g., to downgrade or pin a version):
```bash
./setup.sh --version 1.90.9 --update
```

### Restoring after JetKVM OS Update
If you update the JetKVM firmware, the init script in `/etc/init.d/` will likely be deleted. To restore it:

```bash
./setup.sh --update
```
This will re-upload the `S22tailscale` script and enable the service again.

## File Structure

*   `setup.sh`: The main script to run on your computer. Orchestrates the download and transfer.
*   `install_on_device.sh`: The script that runs *on* the JetKVM to handle extraction and installation.
*   `S22tailscale`: The init script installed to `/etc/init.d/` on the device.
*   `.env`: Configuration file (ignored by git).

## Troubleshooting

*   **"NoState" error**: The script includes a wait loop to ensure Tailscale is fully initialized. If you see this, try running `./setup.sh --update` again.
*   **SSH Connection failed**: Ensure you have added your public key to the JetKVM in Developer Mode and that you can SSH into it manually (`ssh root@<ip>`).

## Init Script Details

The `S22tailscale` init script is designed to be robust and reliable in the JetKVM's embedded environment.

*   **Network Waiting**: It actively waits for the `tun` device and the default network route to be available before starting Tailscale. This prevents startup failures on reboot when the network stack isn't fully ready.
*   **PID Management**: It uses a PID file located in `/tmp/tailscaled.pid` (since `/var/run` may not be writable) to track the running process.
*   **Idempotency**: The script checks if Tailscale is already running before attempting to start it, preventing duplicate processes.
*   **Commands**: Supports `start`, `stop`, `restart`, and `status` commands.

## References & Credits

This project was made possible thanks to the detailed research and guides provided by:

*   [Shane's World: JetKVM Tailscale](https://shanemcd.com/posts/04-jetkvm-tailscale) - Critical information on the init script and network waiting logic.
*   [Brandon Tuttle: Installing Tailscale on a JetKVM](https://scribe.rip/@brandontuttle/installing-tailscale-on-a-jetkvm-3c72355b7eb0) - Guide on the installation process and workarounds.