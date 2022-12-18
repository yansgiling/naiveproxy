#!/bin/bash


#读取域名信息
read -p "Please type your website url:" URL
read -p "Please type your naive username:" USERNM
read -p "Please type your naive password:" PASSWD
read -p "Please type your local port:" PORT

sleep 2s
#更新系统
apt update && apt upgrade -y

#下载Go语言包并安装
wget https://go.dev/dl/go1.19.linux-amd64.tar.gz
tar -zxvf go1.19.linux-amd64.tar.gz -C /usr/local/
echo export PATH=$PATH:/usr/local/go/bin  >> /etc/profile
source /etc/profile
go version
sleep 2s

#下载caddy并编译naive
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
echo "Caddy with Naive has been installed successfully!"
sleep 2s
cp caddy /usr/bin/
/usr/bin/caddy version
sleep 2s
setcap cap_net_bind_service=+ep /usr/bin/caddy

#添加Caddyfile
mkdir /etc/caddy
touch /etc/caddy/Caddyfile
cat <<EOF > /etc/caddy/Caddyfile
:443, $URL
tls 1234@abc.com
route {
  forward_proxy {
    basic_auth $USERNM $PASSWD
    hide_ip
    hide_via
    probe_resistance
  }
   reverse_proxy https://bing.com {
    header_up Host {upstream_hostport}
  }
}
EOF
caddy fmt --overwrite /etc/caddy/Caddyfile
sleep 2s

#启动配置文件
timeout -k 1s 20s caddy run --config /etc/caddy/Caddyfile
sleep 2s


#安装守护进程开机自启动
touch /etc/systemd/system/naive.service
cat <<EOF > /etc/systemd/system/naive.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target
[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable naive
systemctl start naive
timeout -k 2s 3s systemctl status naive
sleep 2s
ss -tulpn | grep caddy
echo "NaiveProxy has been installed successfully!"
sleep 10s

#提供本地cofig.json文件
clear
echo "Copy the context below as your local config.json file"
cat <<EOF
{
   "listen": "socks://127.0.0.1:$PORT",
   "proxy": "https://$USERNM:$PASSWD@$URL",
   "log": ""
}
EOF