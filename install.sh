#!/bin/sh

echo "[*] Installing ZRAM 4GB configuration for SailfishOS..."

# Scarica lo script zram4
echo "[*] Downloading zram4..."
curl -s -L https://raw.githubusercontent.com/RootGPT-YouTube/ZRAM-4Gb-on-Sony-Xperia-10-III-with-SailfishOS/main/zram4 -o /usr/local/sbin/zram4
chmod 755 /usr/local/sbin/zram4

# Scarica il servizio systemd
echo "[*] Downloading zram-override.service..."
curl -s -L https://raw.githubusercontent.com/RootGPT-YouTube/ZRAM-4Gb-on-Sony-Xperia-10-III-with-SailfishOS/main/zram-override.service -o /etc/systemd/system/zram-override.service
chmod 644 /etc/systemd/system/zram-override.service

# Ricarica systemd
echo "[*] Reloading systemd..."
systemctl daemon-reload

# Abilita il servizio
echo "[*] Enabling service..."
systemctl enable zram-override.service

# Avvia il servizio subito
echo "[*] Starting service..."
systemctl start zram-override.service

echo "[✓] Installation complete!"
echo "Reboot recommended."
