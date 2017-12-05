#!/bin/bash
#
#该脚本的作用是初始化阿里云机器，并进行加固。

#将history.sh文件放置于跟该脚本同级目录
#定义ssh使用的端口
OpenSSH_port=51804
dropbear_port=22
#是否使用密码方式登录，no则表示不允许
pass_login=yes
#是否允许root用户直接登录，no则表示不允许
root_login=yes

if [ -d /etc/yum.repos.d/backup ];then
	echo "aliyun"	
else
	cd /etc/yum.repos.d/
	mkdir backup
	mv *.repo ./backup
	wget -O ./CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
	yum clean all
  	yum makecache
  	yum -y update
fi

#使用版本2，centos7不允许使用1版本
sed -i '1,$s/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
#更改默认端口
sed -i '1,$s/#Port 22/Port '"$OpenSSH_port"'/' /etc/ssh/sshd_config
#密码尝试不能超过4次
sed -i '1,$s/#MaxAuthTries 6/MaxAuthTries 4/' /etc/ssh/sshd_config
#输入密码时间为1分钟
sed -i '1,$s/#LoginGraceTime 2m/LoginGraceTime 1m/' /etc/ssh/sshd_config

#禁止直接root用户登录
[ $pass_login == no ] && sed -i '1,$s/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && echo "已禁止使用root直接登录"
#禁止使用密码方式登录
[ $root_login == no ] && sed -i '1,$s/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && echo "已禁止使用密码登录"

sshd -t &> /dev/null
if [ $? -eq 0 ];then
	systemctl restart sshd
else
	echo "sshd修改配置有误，请检查"
	sshd -t
fi

#安装其他远程工具，并占用22端口
dropbear -V &> /dev/null 
[ $? -ne 0 ] && yum install -y dropbear && echo "OPTIONS=\"-m -w -s -g -j -k\"" >> /etc/sysconfig/dropbear && systemctl enable dropbear && systemctl start  dropbear


#验证
lsof -v &> /dev/null
[ $? -ne 0 ] && yum install -y lsof

lsof -n -i:$dropbear_port| grep dropbear &> /dev/null
[ $? -eq 0 ] && echo "dropbear安装成功，监听于22端口"
lsof -n -i:$OpenSSH_port| grep sshd &> /dev/null
[ $? -eq 0 ] && sshd -t && [ $? -eq 0 ] && echo "sshd安装成功，监听于51804端口" 


if [ -e ./history.sh ];then
	touch /etc/profile.d/history.sh
	cat history.sh > /etc/profile.d/history.sh
	source /etc/profile
fi
