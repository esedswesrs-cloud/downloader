#!/usr/bin/env bash
#
# Install Cobalt API TANPA Docker di Ubuntu (langsung via Node.js).
# Cocok untuk VPS/VM yang kernelnya diblokir untuk Docker (OpenVZ/LXC)
# maupun VM biasa.
#
# Cara pakai (satu baris):
#   curl -fsSL https://downloader-pribadi.pages.dev/cobalt-install-ubuntu.sh | bash
#
# Hasil: cobalt jalan di http://localhost:9000/ dan otomatis aktif
# lagi setiap VM reboot (systemd; fallback tmux bila systemd tak ada).
#
set -e

COBALT_DIR="$HOME/cobalt"
ARCH="$(uname -m)"

say() { echo "=== $* ==="; }

say "1/6 - Install Node.js 22, git, pnpm"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs git curl openssl
sudo npm install -g pnpm
command -v pnpm >/dev/null || { echo "pnpm tidak ketemu di PATH, batal."; exit 1; }
PNPM_BIN="$(command -v pnpm)"

say "2/6 - Workaround DNS Ubuntu (nscd, untuk ffmpeg)"
sudo apt-get install -y nscd || true
sudo service nscd start || true

say "3/6 - Clone & install cobalt"
if [ -d "$COBALT_DIR" ]; then
  git -C "$COBALT_DIR" pull || true
else
  git clone https://github.com/imputnet/cobalt "$COBALT_DIR"
fi
cd "$COBALT_DIR/api"
"$PNPM_BIN" install

say "4/6 - Tulis .env"
if [ ! -f .env ]; then
  JWT_SECRET="$(openssl rand -hex 32)"
  cat > .env <<EOF
# URL publik instance ini (ganti ke URL tunnel/domain bila sudah ada)
API_URL="http://localhost:9000/"

# Rahasia JWT (dibuat acak otomatis saat install)
JWT_SECRET="$JWT_SECRET"

# --- Verifikasi Turnstile (opsional, untuk dipakai publik) ---
# Buat site di dash.cloudflare.com -> Turnstile (gratis),
# daftarkan domain web-mu, lalu buka 2 baris ini dan isi:
# TURNSTILE_SITEKEY="0x..."
# TURNSTILE_SECRET="0x..."
EOF
  echo "    .env dibuat (API_URL + JWT_SECRET acak)"
else
  echo "    .env sudah ada - tidak diubah"
fi

say "5/6 - Install yt-dlp (untuk YouTube)"
if [ "$ARCH" = "x86_64" ]; then
  sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp
  sudo chmod +x /usr/local/bin/yt-dlp
else
  sudo apt-get install -y python3-pip
  pip3 install -U --break-system-packages yt-dlp 2>/dev/null || pip3 install -U yt-dlp
fi

say "6/6 - Daftarkan agar jalan otomatis saat boot"
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  sudo tee /etc/systemd/system/cobalt.service > /dev/null <<EOF
[Unit]
Description=Cobalt API (tanpa Docker)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$COBALT_DIR/api
ExecStart=$PNPM_BIN start
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now cobalt
  echo "    service 'cobalt' aktif via systemd"
else
  echo "    systemd tidak tersedia di VM ini - pakai tmux sebagai gantinya"
  sudo apt-get install -y tmux
  tmux kill-session -t cobalt 2>/dev/null || true
  tmux new -d -s cobalt "cd $COBALT_DIR/api && $PNPM_BIN start"
  echo "    cobalt jalan di tmux session 'cobalt'"
fi

echo ""
say "SELESAI - tes mesin:"
sleep 4
curl -s --max-time 10 http://localhost:9000/ | head -c 300; echo
echo ""
echo "Perintah berguna:"
echo "  status : sudo systemctl status cobalt   (tanpa systemd: tmux attach -t cobalt)"
echo "  log    : journalctl -u cobalt -f"
echo "  restart: sudo systemctl restart cobalt"
echo ""
echo "Langkah berikutnya (opsional, untuk akses publik via HTTPS):"
echo "  1) install cloudflared, 2) jalankan: cloudflared tunnel --url http://localhost:9000"
echo "  3) isi URL tunnel itu di web downloader -> Pengaturan -> URL API instance"
