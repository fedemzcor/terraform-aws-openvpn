#!/bin/bash
sudo apt-get -y update
sudo add-apt-repository universe -y 
sudo add-apt-repository ppa:certbot/certbot -y
sudo apt-get install software-properties-common -y
sudo apt-get install -y curl vim libltdl7 python3 python3-pip python software-properties-common unattended-upgrades 
sudo apt-get -y update
sudo apt-get -y install certbot
sudo service openvpnas stop
sudo certbot certonly --standalone --non-interactive --agree-tos --email $1 --domains $2 --pre-hook 'service openvpnas stop' --post-hook 'service openvpnas start'
sudo ln -s -f /etc/letsencrypt/live/$2/cert.pem /usr/local/openvpn_as/etc/web-ssl/server.crt
sudo ln -s -f /etc/letsencrypt/live/$2/privkey.pem /usr/local/openvpn_as/etc/web-ssl/server.key
sudo service openvpnas start