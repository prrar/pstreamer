#!/bin/bash
set -e

if [ x$UID != x0 ]; then
    echo -e "ERRO: rodar como root"
    exit 2
fi

# instala os pacotes necessarios
apt install --no-install-recommends -y build-essential alsa-utils libasound2-dev pkg-config build-essential git autoconf automake libtool libpopt-dev libconfig-dev libasound2-dev avahi-daemon libavahi-client-dev libssl-dev libsoxr-dev libplist-dev libsodium-dev libavutil-dev libavcodec-dev libavformat-dev uuid-dev libgcrypt-dev xxd ffmpeg cifs-utils

# bloqueia o driver interno de som do Mac Mini
echo "blacklist snd_hda_intel" | tee /etc/modprobe.d/sound-blacklist.conf

# faz download dos apps
git clone https://github.com/librespot-org/librespot.git
git clone https://github.com/mikebrady/nqptp.git
git clone https://github.com/mikebrady/shairport-sync.git

# instala rust para o librespot
curl -o rust.sh https://sh.rustup.rs -sSf
chmod +x rust.sh
./rust.sh -y
rm rust.sh
. "$HOME/.cargo/env"
# compila e instala librespot
cd librespot
cargo build --no-default-features --features "alsa-backend" --release
cp ./target/release/librespot /usr/local/bin
cd ..
cat > /etc/systemd/system/spotify.service << END_SPOTIFY
[Unit]
Description=Spotify Connect
Wants=network.target sound.target
After=network.target sound.target

[Service]
DynamicUser=yes
SupplementaryGroups=audio
Restart=always
RestartSec=10
ExecStart=/usr/local/bin/librespot --name "McIntosh" --device-type "speaker" --bitrate 320 --format S16 --initial-volume 100

[Install]
WantedBy=multi-user.target
END_SPOTIFY
systemctl enable --now spotify

# compila e instala o NQPTP
cd nqptp
autoreconf -fi
./configure --with-systemd-startup
make
make install
cd ..
systemctl enable --now nqptp

# compila e instala o shairport
cd shairport-sync
autoreconf -fi
./configure --sysconfdir=/etc --with-alsa --with-soxr --with-avahi --with-ssl=openssl --with-systemd --with-airplay-2
make
make install
cd ..
mv /etc/shairport-sync.conf /etc/shairport-sync.conf.bak
cat > /etc/systemd/system/airplay.service << END_AIRPLAY
[Unit]
Description=AirPlay
After=sound.target
Requires=avahi-daemon.service
After=avahi-daemon.service
Wants=network-online.target
After=network.target network-online.target

[Service]
ExecStart=/usr/local/bin/shairport-sync --log-to-syslog
Restart=always
RestartSec=10
User=shairport-sync
Group=shairport-sync

[Install]
WantedBy=multi-user.target
END_AIRPLAY
systemctl enable --now airplay

# instala o Roon Server
wget https://download.roonlabs.net/builds/RoonServer_linuxx64.tar.bz2
tar xf RoonServer_linuxx64.tar.bz2
mv RoonServer /opt
cat > /etc/systemd/system/roonserver.service << END_SYSTEMD
[Unit]
Description=Roon Server
After=network-online.target

[Service]
Type=simple
User=root
Environment=ROON_DATAROOT=/var/roon
Environment=ROON_ID_DIR=/var/roon
ExecStart=/opt/RoonServer/start.sh
Restart=on-abort

[Install]
WantedBy=multi-user.target
END_SYSTEMD
systemctl enable --now roonserver.service

rm -r librespot
rm -r nqptp
rm -r shairport-sync
rm RoonServer_linuxx64.tar.bz2

echo "PSTREAMER INSTALADO COM SUCESSO! REINICIE O MAC MINI!"

