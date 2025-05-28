Примечание
Если вдруг не обновляются репозитории и связь долбится в ftp.altlinux.org, то делаем следующее:

mcedit /etc/apt/sources.list.d/alt.list
ftp.altlinux.ru - в трёх раскомментированных строчках посередине меняю .org на .ru
 
Первый модуль
1.	Базовая настройка ISP
apt-get update && apt-get install nano iptables tzdata -y
nano /etc/hostname
ISP - меняю имя!

nano /etc/sysconfig/network
HOSTNAME=ISP - поменял имя!

cd /etc/net/ifaces/
cp -r enp6s19 enp6s20
cp -r enp6s19 enp6s21
cd enp6s20

nano options
BOOTPROTO=static
TYPE=eth
SYSTEMD_BOOTPROTO=static  
CONFIG_IPV4=yes  

nano ipv4address
172.16.4.1/28

cp options /etc/net/ifaces/enp6s21
cd ..
cd enp6s21
nano ipv4address
172.16.5.1/28
cd ..
cd ..
nano sysctl.conf
net.ipv4.ip_forward = 1

service network restart
ping ya.ru
iptables -t nat -A POSTROUTING -s 172.16.4.0/28 -o enp6s19 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.5.0/28 -o enp6s19 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables
service iptables start

nano /etc/crontab
@reboot root service iptables start
reboot

ping ya.ru -I 172.16.4.1
ping ya.ru -I 172.16.5.1

ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
 
2.	Настройка адресации и маршрутизации на HQ-RTR
en
conf t
hostname hq-rtr.au-team.irpo
int isp 
ip address 172.16.4.14/28
ip nat outside
int 100 
ip address 192.168.1.1/26
ip nat inside 
int 200
ip address 192.168.1.65/28
ip nat inside
int 999
ip address 192.168.1.81/29
ip nat inside
port ge0
service-instance isp
encapsulation untagged 
connect ip interface isp 
port ge1
service-instance 100 
encapsulation dot1q 100
rewrite pop 1
connect ip interface 100
ex
service-instance 200
encapsulation dot1q 200
rewrite pop 1
connect ip interface 200
ex
service-instance 999
encapsulation dot1q 999
rewrite pop 1
connect ip interface 999
ex
ip route 0.0.0.0/0 172.16.4.1
ip name-server 77.88.8.8
ip nat pool INTERNET 192.168.1.1-192.168.1.87
ip nat source dynamic inside-to-outside pool INTERNET overload 172.16.4.14
int tunnel.1
ip address 10.10.10.9/30
ip tunnel 172.16.4.14 172.16.5.14 mode gre
ip ospf  authentication-key P@ssw0rd
ip ospf  authentication message-digest
ex
router ospf 1
network 10.10.10.8/30 area 0
network 192.168.1.0/26 area 0
network 192.168.1.64/28 area 0
network 192.168.1.80/29 area 0
passive-interface isp 
passive-interface 100
passive-interface 200
passive-interface 999
area 0 authentication message-digest
ex
do wr
 
3.	Настройка адресации и маршрутизации на BR-RTR
en
conf t
hostname br-rtr.au-team.irpo
int isp
ip address 172.16.5.14/28
ip nat outside
int lan 
ip address 192.168.2.1/27
ip nat inside
port ge0
service-instance isp
encapsulation untagged
connect ip interface isp
port ge1
service-instance lan
encapsulation untagged
connect ip interface lan
ex
ex
ip route 0.0.0.0/0 172.16.5.1
ip name-server 77.88.8.8
ip nat pool INTERNET 192.168.2.1-192.168.2.30
ip nat source dynamic inside-to-outside pool INTERNET overload 172.16.5.14
int tunnel.1
ip address 10.10.10.10/30
ip tunnel 172.16.5.14 172.16.4.14 mode gre
ip ospf  authentication-key P@ssw0rd
ip ospf  authentication message-digest
ex
router ospf 1
network 10.10.10.8/30 area 0
network 192.168.2.0/27 area 0
area 0 authentication message-digest
passive-interface isp 
passive-interface lan
ex
do wr
 
4.	Настройка свитча HQ-SW
hostnamectl hostname hq-sw.au-team.irpo; exec bash
cd /etc/net/ifaces
cp -r ens19 ens20
cp -r ens19 ens21
mkdir mgmt
cd mgmt/

mcedit options
TYPE=ovsport
BRIDGE=hq-sw
VID=999

echo 192.168.1.82/29 > ipv4address
echo default via 192.168.1.81 > ipv4route
echo nameserver 77.88.8.8 > resolv.conf
cd ..

mcedit sysctl.conf
net.ipv4.ip_forward = 1

systemctl enable --now openvswitch.service
ovs-vsctl add-br hq-sw
ovs-vsctl add-port  hq-sw ens19 trunks=100,200,999
ovs-vsctl add-port  hq-sw ens20 tag=100
ovs-vsctl add-port  hq-sw ens21 tag=200
reboot
ping ya.ru
timedatectl set-timezone Europe/Moscow 
5.	Настройка DNS-сервера HQ-SRV
hostnamectl hostname hq-srv.au-team.irpo; exec bash
cd /etc/net/ifaces/ens19
echo 192.168.1.2/26 > ipv4address
echo default via 192.168.1.1 > ipv4route
echo nameserver 77.88.8.8 > resolv.conf
systemctl restart network
apt-get update && apt-get install nano bind bind-utils -y
cd /etc/bind/

nano named.conf
#include “/etc/bind/rndc.conf”; - комментирую строку, не пишу!

nano options.conf
listen-on { 192.168.1.2; }; - меняю адрес на этот!
//listen-on-v6 { ::1;}; - комментируем строку, не пишу!
forwarders { 77.88.8.8; }; - раскомментировал и записал адрес!
allow-query { any; }; - раскомментировал и записал значение!
allow-query-cache { any; }; - раскомментировал и записал значение!
allow-recursion { any; }; - раскомментировал и записал значение!

nano local.conf
zone “au-team.irpo” {
	type master;
	file “/etc/bind/zone/db.au”;
};
zone “1.168.192.in-addr.arpa” {
	type master;
	file “/etc/bind/zone/db.reverse”;
};
cd zone
cp localhost db.au

nano db.au
Ctrl \ - сочетание клавиш!
localhost
au-team.irpo
A - нажимаю!
IN	A	192.168.1.2 - меняю адрес на этот!

cp db.au db.reverse
chown root:named db.*

nano db.au
hq-srv IN	A	192.168.1.2
hq-rtr IN	A	192.168.1.1
hq-rtr IN	A	192.168.1.65
hq-rtr IN	A	192.168.1.81
br-srv IN	A	192.168.2.2
br-rtr IN	A	192.168.2.1
hq-cli IN	A	192.168.1.66
moodle IN	A	172.16.4.1
wiki IN	A	172.16.5.1

nano db.reverse
1	IN	PTR	hq-rtr.au-team.irpo.
65	IN	PTR	hq-rtr.au-team.irpo.
81	IN	PTR	hq-rtr.au-team.irpo.
2	IN	PTR	hq-srv.au-team.irpo.
66	IN	PTR	hq-cli.au-team.irpo.
systemctl restart bind
cd /etc/net/ifaces/{доступный интерфейс}

nano resolv.conf
nameserver 192.168.1.2
search au-team.irpo

systemctl restart network
systemctl restart bind
systemctl enable --now bind
host hq-srv
host 192.168.1.2
host wiki
host ya.ru
 
6.	Смена DNS-сервера на обеих RTR
en
conf t
no ip name-server 77.88.8.8
ip name-server 192.168.1.2
ip domain-name au-team.irpo
do ping hq-srv
do wr
 
7.	Настройка DHCP-сервера на HQ-RTR
ip pool hq 192.168.1.67-192.168.1.78
dhcp-server 1
static ip 192.168.1.66
client-id mac {mac-адрес hq-cli}
mask 255.255.255.240
gateway 192.168.1.65
dns 192.168.1.2
domain-search au-team.irpo
ex
pool hq 1
mask 255.255.255.240
gateway 192.168.1.65
dns 192.168.1.2
domain-search au-team.irpo
ex
ex
ex
int 200
dhcp-server 1
do wr
 
8.	Базовая настройка HQ-CLI
hostnamectl hostname hq-cli.au-team.irpo; exec bash
timedatectl set-timezone Europe/Moscow
ping ya.ru
host hq-srv
 
9.	Базовая настройка BR-SRV
hostnamectl hostname br-srv.au-team.irpo; exec bash
cd /etc/net/ifaces/ens19
echo 192.168.2.2/27 > ipv4address
echo default via 192.168.2.1 > ipv4route

nano resolv.conf
nameserver 192.168.1.2
search au-team.irpo

systemctl restart network
ping ya.ru
ping hq-srv
ping wiki
 
10.	Настройка времени и создание админов на обеих RTR
ntp timezone utc+3
username net_admin
password P@$$word
role admin
ex
do wr
 
11.	Настройка учёток, пользаков, времени на обеих SRV
useradd -m sshuser -u 1010 -s /bin/bash
passwd sshuser
P@ssw0rd - два раза!
usermod -aG wheel sshuser

mcedit /etc/sudoers
WHEEL_USERS ALL=(ALL:sshuser) NOPASSWD: ALL - раскомментировал и записал значение!

su - sshuser
sudo vim

nano /etc/openssh/sshd_config
Port 2024 - раскомментировал и записал значение!
AllowUsers sshuser - написал вручную!
MasAuthTries 2 - раскомментировал и записал значение!
Banner /etc/banner.net - раскомментировал и записал значение!

nano /etc/banner.net
Authorized Access Only - после этого нажать энтер и уже потом сохранить!

systemctl restart sshd.service
ssh -p 2024 sshuser@localhost
exit

timedatectl set-timezone Europe/Moscow 
Второй модуль
1.	Настройка Samba на BR-SRV
apt-get update && apt-get install task-samba-dc alterator-{fbi,net-domain} admx-* admc gpui git -y 
systemctl enable --now ahttpd alteratord
domainname au-team.irpo

mcedit /etc/sysconfig/network
HOSTNAME=br-srv.au-team.irpo - меняю значение на это!

rm -rf /etc/samba/smb.conf /var/{lib,cache}/samba
mkdir -p /var/lib/samba/sysvol
samba-tool domain provision --realm=au-team.irpo --domain=au-team --adminpass=’P@ssw0rd’ --dns-backend=BIND9_DLZ --server-role=dc --use-rfc2307
Идём на клиента ниже на пункт 2!
git clone https://github.com/Wrage-ru/parse-csv.git
cd parse-csv/
mv example.csv /opt/users.csv
chmod +x create-user.sh
./create-user.sh /opt/users.csv
samba-tool group add hq
for i in $(seq 1 5); do samba-tool user add user$i.hq ‘P@ssw0rd’; done
for i in $(seq 1 5); do samba-tool group addmembers hq user$i.hq; done
admx-msi-setup
samba-tool computer add moodle --ip-address=172.16.4.1 -U Administrator
samba-tool computer add wiki --ip-address=172.16.5.1 -U Administrator
samba-tool computer add HQ-SRV --ip-address=192.168.1.2 -U Administrator
samba-tool computer add mon --ip-address=192.168.1.2 -U Administrator
 
2.	Ввод в домен и настройка Samba на HQ-CLI
apt-get update && apt-get install admx-* admc gpui sudo gpupdate -y
Переходим в Firefox по адресу 192.168.2.2:8080, должен открыться центр управления системой.
Нажимаем Настройка
 

Режим эксперта - Применить
 

Переходим в раздел Веб-интерфейс
 

Меняем порт с 8080 на 8081 - Применить - Перезапустить HTTP-сервер
 
Переходим в раздел Домен, меняем адрес на 192.168.2.2, пароль админа - P@ssw0rd, Применить 
 

В случае успеха, должны поменяться значения текущего состояния:
 

В параметрах проводного соединения указываем доп. серверы DNS - 192.168.2.2, потом включаем и отключаем поддержку сети
 
Возвращаемся в терминал
acc
В разделе Пользователи нажимаем на Аутентификация 
 

Дописываем рабочую группу au-team, Применить
 

Успешно выполнение
 

Возвращаемся на BR-SRV выше к git clone!
Заходим под Administrator, пароль P@ssw0rd
su -
admx-msi-setup
roleadd hq wheel

mcedit /etc/sudoers
User_Alias		WHEEL_USERS = %wheel, %AU-TEAM\\hq - дописал!
Cmnd_Alias		SHELLCMD = /usr/bin/id, /bin/cat, /bin/grep - написал новую строчку!
WHEEL_USERS ALL=(ALL:ALL) SHELLCMD - раскомментировал и поменял с ALL на SHELLCMD!

Выходим из рута
kinit
admc

Раскрываем Объекты групповой политики, ПКМ по au-team.irpo - Создать политику и связать с этим подразделением
 

Называем sudoers
 

Ставим галочку на Принудительно
 

ПКМ по sudoers - Edit
 

Переходим по пути Компьютер - Административные шаблоны - Samba - Настройки Unix - Управлением разрешениями Sudo, состояние политики - Включено, Редактировать
 

Добавляем три поля, прописываем /usr/bin/id в первом, /bin/cat во втором, /bin/grep в третьем, потом нажимаем ОК
 

Нажимаем ОК в правом нижнем углу, закрываем окна, возвращаемся в терминал
gpupdate -f
Выходим из текущего пользователя
Заходим под пользователем user3.hq - Пароль P@ssw0rd
Заходим в терминал
sudo id
sudo cat /root/.bashrc
 
3.	Конфигурация файлового хранилища на HQ-SRV
lsblk - необходимы три диска для raid (sdb, sdc, sdd)
mdadm -C /dev/md0 -l 5 -n 3 /dev/sd{b,c,d}
lsblk - проверяем, что диски sdb, sdc, sdd в raid5
mkfs.ext4 /dev/md0
echo DEVICE partitions >> /etc/mdadm.conf
mdadm --detail --scan >> /etc/mdadm.conf
mkdir /raid5

mcedit /etc/fstab
/dev/md0	/raid5	ext4	defaults	0	0

mount -a
df -h - убедиться, что md0 в raid5

apt-get install nfs-{server,utils} -y
mkdir /raid5/nfs
chmod 777 /raid5/nfs/

mcedit /etc/exports
#/srv/public -ro,insecure,nosubtree_check,fsid=1 * - комментирую строку!
/raid5/nfs 192.168.1.64/28(rw,no_subtree_check,no_root_squash)

exportfs -arv
systemctl enable --now nfs-server.service
 
4.	Настройка автомонтирования на HQ-CLI
mkdir /mnt/nfs
chmod 777 /mnt/nfs

mcedit /etc/fstab
192.168.1.2:/raid5/nfs	/mnt/nfs	nfs	defaults	0	0

mount -a
df -h - убедиться, что отображается адрес hq-srv
 
5.	Настройка chrony-сервера на ISP
apt-get install chrony -y

nano /etc/chrony.conf
pool 0.ru.pool.ntp.org iburst - дописал!
local stratum 5
allow 0.0.0.0/0

systemctl restart chronyd
systemctl enable --now chronyd
chronyc clients - выполнить команду после настройки клиентов ниже! должны быть клиенты 172.16.4.14 и 172.16.5.14, это нормально!
 
6.	Настройка ntp-клиента на обеих RTR
en
conf t
ntp server 172.16.4.1 - только на HQ-RTR
ntp server 172.16.5.1 - только на BR-RTR
do wr
 
7.	Настройка chrony-клиента на обеих SRV и HQ-CLI
mcedit /etc/chrony.conf
pool 172.16.4.1 iburst - только на hq-srv и hq-cli
pool 172.16.5.1 iburst - только на br-srv

systemctl restart chronyd
systemctl enable --now chronyd
chronyc sources - убедиться, что отобразился сервер chrony и не забудь проверить клиентов на ISP!
 
8.	Настройка ssh на HQ-CLI для ansible
mcedit /etc/openssh/sshd_config
AllowUsers sysadmin - написал вручную!
Port 2024 - раскомментировал и поменял значение!
MasAuthTries 2 - раскомментировал и поменял значение!
PunkeyAuthentication yes - раскомментировал!
PasswordAuthentication yes - раскомментировал!

systemctl restart sshd
systemctl enable --now sshd
 
9.	Настройка ansible на BR-SRV
apt-get update && apt-get install ansible sshpass -y
cd /etc/ansible/

mcedit hosts
[Eco]
192.168.1.1
192.168.2.1

[Eco:vars]
ansible_ssh_user=admin
ansible_ssh_pass=admin
ansible_connection=network_cli 
ansible_network_os=ios

[Alt]
192.168.1.2 ansible_ssh_user=sshuser ansible_ssh_pass=P@ssw0rd
192.168.1.66 ansible_ssh_user=sysadmin ansible_ssh_pass=toor

[Alt:vars]
ansible_port =2024

mcedit ansible.cfg
[defaults]
interpreter_python = /usr/bin/python3 - написал вручную!
host_key_checking = False - раскомментировал!

ansible -m ping all - убедиться, что у всех четырёх устройств зелёный цвет и pong!
 
10.	Настройка Docker на BR-SRV
apt-get install docker-ce docker-compose -y
Пока устанавливается, идём на HQ-CLI ниже и настраиваем там, после установки пишем тут!
systemctl enable --now docker.socket docker.service
Возвращаемся на HQ-CLI!

 
11.	Настройка HQ-CLI для Docker
Запускаем Firefox, переходим по адресу hub.docker.com, ищем в поиске mediawiki, выбираем репозиторий с оранжевым кольцом, ниже ищем пример кода docker-compose.yml

Запускаем терминал
ssh -p 2024 sshuser@192.168.2.2
su -

mcedit wiki.yml
Копируем сюда тот самый пример кода на сайте
services:
  wiki:  - удалил часть слова media!
    image: mediawiki
    restart: always
    ports:
      - 8080:80
    links:
      - mariadb  - заменил на это!
    volumes:
      - images:/var/www/html/images
      # - ./LocalSettings.php:/var/www/html/LocalSettings.php
  mariadb: - заменил на это!
    image: mariadb
    restart: always
    environment:
      MYSQL_DATABASE: mediawiki - заменил на это!
      MYSQL_USER: wiki - заменил на это!
      MYSQL_PASSWORD: WikiP@ssw0rd - заменил на это!
      MYSQL_RANDOM_ROOT_PASSWORD: 'yes'
    volumes:
      - db:/var/lib/mysql

volumes:
  images:
  db:

Возвращаемся на BR-SRV и ждем пока установится докер!
docker compose -f wiki.yml up -d - ждём пока все запустится!

Заходим в Firefox и переходим по адресу 192.168.2.2:8080
Нажимаем на set up the wiki
 

Далее
 

Листаем вниз - Далее
 

Пишем в строчках: хост базы данных: mariadb, имя БД - mediawiki, имя пользователя БД - wiki, пароль БД - WikiP@ssw0rd, нажимаем Далее
 

Далее
 

Название вики - wiki, имя участника - wiki, пароль - WikiP@ssw0rd, снимаем галочку с «Поделиться сведениями...», выбрать «Хватит уже, просто…», Далее
 

Далее 
 

Далее
 

У нас загрузится файл LocalSettings.php
 

Открываем терминал в папке Загрузки
 

scp -P 2024 LocalSettings.php sshuser@192.168.2.2:/home/sshuser 

Так же на клиенте открываем терминал, где у нас уже есть подключение к BR-SRV
mv /home/sshsuser/LocalSettings.php .

mcedit wiki.yml
    - ./LocalSettings.php:/var/www/html/LocalSettings.php - раскомментировал строку!

docker compose -f wiki.yml down
docker compose -f wiki.yml up -d

Заходим в Firefox и переходим по адресу 192.168.2.2:8080, видим, что главная страница поменялась, нажимаем Войти в правом верхнем углу

Авторизуемся
 
 
12.	Настройка статической трансляции портов на HQ-RTR
en
conf t
ip nat destination static tcp 172.16.4.14 2024 192.168.1.2 2024 hairpin
ip nat source static tcp 192.168.1.2 2024 172.16.4.14 2024
ip nat destination static tcp 172.16.4.14 80 192.168.1.2 80 hairpin
ip nat source static tcp 192.168.1.2 80 172.16.4.14 80
do wr
 
13.	Настройка статической трансляции портов на BR-RTR
en
conf t
ip nat destination static tcp 172.16.5.14 2024 192.168.2.2 2024 hairpin
ip nat source static tcp 192.168.2.2 2024 172.16.5.14 2024
ip nat destination static tcp 172.16.5.14 80 192.168.2.2 8080 hairpin
ip nat source static tcp 192.168.2.2 8080 172.16.5.14 80
do wr
 
14.	Проверка работы трансляции портов на HQ-CLI и BR-SRV
ssh -p 2024 sshuser@172.16.4.14
exit
ssh -p 2024 sshuser@172.16.5.14 
exit
Заходим в Firefox по адресу 172.16.5.14 и должно быть перенаправление на 192.168.2.2:8080
 
15.	Настройка moodle на HQ-SRV
apt-get install deploy -y

mcedit /usr/share/deploy/moodle/tasks/main.yml
F4 - заменяем moodle1 на moodledb для всех
Еще раз F4 - заменяем moodleuser  на moodle для всех
-name: generate password for Moodle
 shell: echo ‘P@ssw0rd’ - заменил на это значение!

deploy moodle
Пока deploy делает прогон, идем ниже на пункт 16 ставить браузер и после того как deploy сделает прогон, идём донастраивать moodle на HQ-CLI
 
16.	Установка Яндекс Браузера для Организаций на HQ-CLI
su -
apt-get install yandex-browser -y
*Личная заметка*
Дальше несколько путей: можно запомнить мою сокращенную ссылку ниже и скачать файл, либо заходить в свой аккаунт на тачке. Наверняка первый вариант кажется всем предпочтительней, поэтому скачиваем отсюда:
goo.su/pHFVM
На 19 мая 2025 версия Яндекс Браузера для Организаций - 25.2.1
Запускаем скаченный файл
 
17.	Донастройка moodle на HQ-CLI
Запускаем браузер и переходим по адресу 192.168.1.2/moodle
В правом верхнем углу нажимаем Вход

Логин - admin, пароль - P@ssw0rd
 

Адрес электронной почты - moodle@au-team.irpo
 

Ниже нажимаем кнопку Обновить профиль
 

В правом верхнем углу включаем режим редактирования
 

Переходим в раздел Настройки и меняем значение Полное название сайта на свой номер рабочего место. У Наумца это 1, у нас в зависимости от того на какое мы сядем на демоэкзамене 

Листаем ниже и нажимаем Сохранить изменения
 

Выключаем режим редактирования и идем в раздел В начало
 
 
18.	Настройка веб-сервера Nginx на ISP
apt-get install nginx -y

nano /etc/nginx/sites-available.d/default.conf
upstream moodle.au-team.irpo {
server 172.16.4.14;
}

server {
listen 80;
server_name _;

location / {
proxy_pass http://moodle.au-team.irpo;
}
}

nano /etc/nginx/sites-available.d/wiki.conf
upstream wiki.au-team.irpo {
server 172.16.5.14:80;
}

server {
listen 8080;
server_name _;

location / {
proxy_pass http://wiki.au-team.irpo;
}
}
ln -s /etc/nginx/sites-available.d/default.conf /etc/nginx/sites-enabled.d/default.conf
ln -s /etc/nginx/sites-available.d/wiki.conf /etc/nginx/sites-enabled.d/wiki.conf
systemctl restart nginx
systemctl reload nginx
systemctl enable --now nginx 
19.	Изменение адреса wiki для Nginx на BR-SRV
cd ~
nano LocalSettings.php
$wgServer = http://wiki.au-team.irpo:8080; - поменял значение!

docker compose -f wiki.yml down
docker compose -f wiki.yml up -d
 
20.	Изменение адреса moodle для Nginx на HQ-SRV
nano /var/www/webapps/moodle/config.php
$CFG->wwwroot = ‘http://moodle.au-team.irpo/moodle’; - поменял значение!

nano /etc/httpd2/conf/sites-enabled/000-default.conf
Листаем в самый конец!
#RewriteEngine On - закомментировал!
#RewriteCond %{HTTPS} !=on - закомментировал!
#RewriteRule ^/(.*) https://%{HTTPS_HOST}/$1 [R,L] - закомментировал!

systemctl restart httpd2
 
Третий модуль
1.	Миграция контроллера домена
Нету
 
2.	Настройка центра сертификации
Нету
 
3.	Шифрование IP-Туннеля
Нету
 
4.	Настройка межсетевого экрана на HQ-RTR
en
conf t
filter-map ipv4 http
match tcp any any eq 80
set accept
exit
filter-map ipv4 https
match tcp any any eq 443
set accept
exit
filter-map ipv4 ntp
match udp any any eq 123
set accept
exit
filter-map ipv4 icmp
match icmp any any 
set accept
exit
filter-map ipv4 dns
match udp any any
set accept
exit
filter-map ipv4 gre
match gre any any
set accept
exit
filter-map ipv4 ospf
match ospf any any
set accept
exit
filter-map ipv4 ssh
match tcp any any
set accept
exit
filter-map ipv4 blk
match any any any
set discard
exit
int isp
set filter-map in dns
set filter-map in gre
set filter-map in ospf
set filter-map in http
set filter-map in https
set filter-map in ntp
set filter-map in icmp
set filter-map in ssh
set filter-map in blk
 
5.	Настройка межсетевого экрана на BR-RTR
en
conf t
filter-map ipv4 http
match tcp any any eq 80
set accept
exit
filter-map ipv4 https
match tcp any any eq 443
set accept
exit
filter-map ipv4 ntp
match udp any any eq 123
set accept
exit
filter-map ipv4 icmp
match icmp any any 
set accept
exit
filter-map ipv4 dns
match udp any any
set accept
exit
filter-map ipv4 gre
match gre any any
set accept
exit
filter-map ipv4 ospf
match ospf any any
set accept
exit
filter-map ipv4 ssh
match tcp any any
set accept
exit
filter-map ipv4 blk
match any any any
set discard
exit
int isp
set filter-map in dns
set filter-map in gre
set filter-map in ospf
set filter-map in http
set filter-map in https
set filter-map in ntp
set filter-map in icmp
set filter-map in ssh
set filter-map in blk
 
6.	Настройка принт-сервера CUPS на HQ-SRV
apt-get install cups cups-pdf -y
systemctl enable --now cups

nano /etc/cups/cupsd.conf
Везде где есть Location дописать Allow all
 

systemctl restart cups
 
7.	Донастройка принт-сервера CUPS на HQ-CLI
su -
lpadmin -x Cups-PDF
lpadmin -p CUPS -E -v ipp://hq-srv.au-team.irpo:631/printers/Cups-PDF -m everywhere
lpadmin -d CUPS
lpstat -p
Печатаем любой док, переходим по адресу принтера https://hq-srv.au-team.irpo:631, Принтеры, Cups-PDF, Показать все задания (должно быть задание со статусом "завершено")
 
8.	Настройка логирования на HQ-SRV и BR-SRV
HQ-SRV:
apt-get install -y rsyslog
mcedit /etc/rsyslog.d/00_common.conf
раскоментировать module(load="imtcp") и input(type="imtcp" port="514")
в конце прописать
$template RemoteLogs, "/opt/%HOSTNAME%/rsyslog.txt"
*.* ?RemoteLogs
& stop
(скрин 1)
скрипт по ротации логов
mcedit /etc/logrotate.d/rsyslog

на BR-SRV:
apt-get install -y rsyslog rsyslog-imjouranl
mcedit /etc/rsyslog.d/08_imjournal.conf
закоментить первую строчку

(скрин 2)
mcedit /etc/rsyslog.d/00_common.conf
раскоментить 1,3,4 module
в первом дописать 
       StateFile="imjournal.state"
       IgnorePreviousMessages="on"
в конце конфигурации указать тип сообщений и сервер логирования (TCP)
*.warning @@192.168.1.2:514
 
9.	Настройка мониторинга на HQ-SRV
apt-get install docker-ce docker-compose -y
systemctl enable --now docker.socket docker.service

mcedit /etc/bind/zone/db.au
mon    IN    A     192.168.1.2
systemctl restart bind

mcedit zabbix.yml
services:
  zabbix-postgres:
    container_name: zabbix-postgres
    image: postgres
    volumes:
      - postgres-zabbix:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: zabbix
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: zabbix
    restart: unless-stopped

  zabbix-server:
    container_name: zabbix-server
    image: zabbix/zabbix-server-pgsql
    environment:
      DB_SERVER_HOST: zabbix-postgres
      DB_SERVER_PORT: 5432
      POSTGRES_DB: zabbix
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: zabbix
    ports:
      - 10051:10051
    restart: unless-stopped
    depends_on:
      - zabbix-postgres

  zabbix-web:
    container_name: zabbix-web
    image: zabbix/zabbix-web-nginx-pgsql
    environment:
      DB_SERVER_HOST: zabbix-postgres
      DB_SERVER_PORT: 5432
      POSTGRES_DB: zabbix
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: zabbix
      ZBX_SERVER_HOST: zabbix-server
      ZBX_SERVER_PORT: 10051
      PHP_TZ: Europe/Moscow
    ports:
      - 8080:8080
    restart: unless-stopped
    depends_on:
      - zabbix-postgres

volumes:
  postgres-zabbix:

docker compose -f zabbix.yml up -d
mcedit /etc/zabbix/zabbix_agentd.conf
Server=0.0.0.0/0
ServerActive=192.168.1.2
Hostname=hq-srv.au-team.irpo
systemctl enable --now zabbix_agentd
 
10.	Настройка агента мониторинга на BR-SRV
mcedit /etc/zabbix/zabbix_agentd.conf
Server=0.0.0.0/0
ServerActive=192.168.1.2
Hostname=br-srv.au-team.irpo

systemctl enable --now zabbix_agentd
 
11.	Настройка веб-интерфейса Zabbix на HQ-CLI
Переходим в браузере по адресу mon.au-team.irpo:8080
Логин, пароль: Admin, zabbix
Users > Authentication и снимаем галочку  Avoid easy-to-guess password, сохраняем
User settings > Profile меняем пароль на P@ssw0rd
Переходим Monitoring > Hosts, нажимаем на Zabbix Server, меняем адрес на 192.168.1.2, Update
Тут же в правом верхнем углу Create host
Указываем hostname - BR-SRV, templates - linux by zabbix agent
Выбираем группу linux servers и указываем адрес agent - 192.168.2.2
Дашбор > edit 
Удаляем не нужные виджиты и добавляем виджиты для хостов
Тип график
Ниже - хост - нужный хост , ram % , cpu utilization, fs space used in %
добавляем для каждой машины и сохраняем изменения дашборда!
 
12.	Настройка инвентаризации через ansible на BR-SRV
mkdir /etc/ansible/PC_INFO/

nano /etc/ansible/playbook.yml
---
- name: Works
  hosts: Alt
  gather_facts: yes
  tasks:
    - name: Create info
      delegate_to: localhost
      copy:
        dest: "/etc/ansible/PC_INFO/{{ ansible_hostname }}.yml"
        content: |
            Имя компьютера: '{{ ansible_hostname }}'
            IP-адрес компьютера: '{{ ansible_default_ipv4.address }}'

ansible-playbook /etc/ansible/playbook.yml - если так не работает, то дописываем -K
ls /etc/ansible/PC_INFO/
cat /etc/ansible/PC_INFO/какой-то файл.yml
 
13.	Механизм резервного копирования через ansible на BR-SRV
Пока нету
