#!/bin/bash

API_PORT=10000
GATEWAY_PORT=15000
P2P_PORT=25000

kill(){

#  local pidnum=$(ps -ef | grep gpfs | grep -v grep | awk '{print $2}')
#  if [ "$pidnum" ]; then
#          kill -9 $pidnum
#          echo killed $pidnum
#  fi
  install_dir="/usr/bin/gpfs"
  ps -ef | grep $install_dir | grep -v grep | awk '{print $2}' | xargs kill -9
  echo gpfs all killed!
}
install(){

if [ ! -e "/tmp/GPFSDOWNLOADLOCK" ]; then
  download
fi

ln -s /usr/bin/python3 /usr/bin/python >/dev/null 2>&1
ufw allow ssh >/dev/null 2>&1
ufw allow 10000:13000/tcp >/dev/null 2>&1
#ufw allow 2100:2500/udp >/dev/null 2>&1
ufw allow 15000:18000/tcp >/dev/null 2>&1
#ufw allow 3100:3500/udp >/dev/null 2>&1
ufw deny out to 10.0.0.0/8
ufw deny out to 172.16.0.0/12
ufw deny out to 192.168.0.0/16
ufw deny out to 100.64.0.0/10
ufw deny out to 169.254.0.0/16
echo y | ufw enable >/dev/null 2>&1
ufw default deny >/dev/null 2>&1

echo '*/10 * * * * /bin/bash /root/gps_install.sh run >> /root/runchk.log 2>&1 &' >/var/spool/cron/crontabs/root
local install_dir='/mnt'
#ps -ef | grep gpfs | grep -v grep | awk '{print $2}' | xargs kill -9

local j=0
while read line
do
  install_dir="/mnt/ipfs$j"
  rm -rf $installdir/config
  let x="$API_PORT+$j"
  let y="$GATEWAY_PORT+$j"
  let z="$P2P_PORT+$j"
  mkdir -p $install_dir
  if [ ! -e "/mnt/GPFSINSTALLLOCK" ]; then
  #export IPFS_PATH=$install_dir && /usr/bin/gpfs init >/dev/null 2>&1
      export IPFS_PATH=$install_dir && /usr/bin/gpfs init && /usr/bin/gpfs config Addresses.Gateway /ip4/127.0.0.1/tcp/$y && /usr/bin/gpfs config Addresses.API /ip4/127.0.0.1/tcp/$x

  else
      export IPFS_PATH=$install_dir && /usr/bin/gpfs config Addresses.Gateway /ip4/127.0.0.1/tcp/$y && /usr/bin/gpfs config Addresses.API /ip4/127.0.0.1/tcp/$x
  fi
  #sleep 1

  ((j++))
  echo "地址$j $line 生成完毕!"
done < bsc.txt
echo "所有地址生成完毕!"
echo SUCCESS>/mnt/GPFSINSTALLLOCK

}

download(){

  echo "Install Required Packages..."
  apt-get update > /dev/null 2>&1 && apt-get install ufw lrzsz unzip curl jq net-tools sudo git vim -y > /dev/null 2>&1

  cd $install_dir && wget https://github.com/gpfs-group/gpfs-mining/releases/download/v0.8.1/linux_amd64.zip
  unzip linux_amd64.zip
  chmod +x linux_amd64/gpfs
  cp linux_amd64/gpfs /usr/bin
  rm -rf linux_amd64*
  echo SUCCESS>/tmp/GPFSDOWNLOADLOCK
  echo "Successfully Download File..."

}
run(){

  echo "----------------------------------------------------------------------------"
  endDate=`date +"%Y-%m-%d %H:%M:%S"`
  echo "★[$endDate] Run Successful"
  echo "----------------------------------------------------------------------------"
  local j=0
  local install_dir='/mnt'
  while read line
  do
     install_dir="/mnt/ipfs$j"
     config_file="$install_dir/config"
     local pidnum=$(ps -ef | grep $line | grep -v grep | awk '{print $2}')
      if [ -z "$pidnum" ]; then
          export IPFS_PATH=$install_dir && nohup /usr/bin/gpfs daemon --miner-address=$line >$install_dir/run.log 2>&1 &
          echo $j started!
          #sleep 1
      fi
      ((j++))

  done < bsc.txt
}
init(){
apt-get update > /dev/null 2>&1 && apt-get install net-tools nload -y > /dev/null 2>&1
local ip=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:")
hostnamectl set-hostname ${ip//./-}

# Systemd

sed  -i s/#DNS=/DNS=8.8.8.8/ /etc/systemd/resolved.conf
systemctl restart systemd-resolved.service
ulimit -HSn 655350
cp /etc/security/limits.conf /etc/security/limits.conf.bak

cat >/etc/security/limits.conf <<EOF
*               hard    nofile          655350
*               soft    nofile          655350
root            hard    nofile          655350
root            soft    nofile          655350
EOF
# /etc/sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat >/etc/sysctl.conf <<EOF

fs.file-max = 655350

net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096        87380   4194304
net.ipv4.tcp_wmem = 4096        16384   4194304

net.ipv4.tcp_max_syn_backlog = 65536
net.core.netdev_max_backlog =  32768
net.core.somaxconn = 32768

net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2

net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1

net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_max_orphans = 3276800

net.ipv4.ip_local_port_range = 5000    65500
kernel.panic = 10
net.ipv6.conf.all.disable_ipv6 = 1
EOF
sed -i '/DefaultLimitNOFILE/c DefaultLimitNOFILE=65535' /etc/systemd/*.conf
systemctl daemon-reexec
sysctl -p >/dev/null 2>&1

}
#*/10 * * * * /bin/bash /root/gps_install.sh run > /root/runchk.log 2>&1 &
case $1 in
init)
  init
  ;;
download)
  download
  ;;
install)
  install
  ;;
kill)
  kill
  ;;
run|"")
  run
  ;;
esac

exit 0