Primechanie
Esli vdrug ne obnovlyayutsya repozitorii i svyaz' dolbitsya v ftp.altlinux.org, to delaem sleduyushchee:

mcedit /etc/apt/sources.list.d/alt.list
ftp.altlinux.ru - v tryoh raskommentirovannyh strochkah poseredine menyayu .org na .ru
 
Pervyj modul'
1.	Bazovaya nastrojka ISP
apt-get update && apt-get install nano iptables tzdata -y
nano /etc/hostname
ISP - menyayu imya!

nano /etc/sysconfig/network
HOSTNAME=ISP - pomenyal imya!

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
172.16.40.1/28

cp options /etc/net/ifaces/enp6s21
cd ..
cd enp6s21
nano ipv4address
172.16.50.1/28
cd ..
cd ..
nano sysctl.conf
net.ipv4.ip_forward = 1

service network restart
ping ya.ru
iptables -t nat -A POSTROUTING -s 172.16.40.0/28 -o enp6s19 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.50.0/28 -o enp6s19 -j MASQUERADE
iptables-save > /etc/sysconfig/iptables
service iptables start

nano /etc/crontab
@reboot root service iptables start
reboot

ping ya.ru -I 172.16.40.1
ping ya.ru -I 172.16.50.1

ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
 
2. HQ-RTR
en
conf t
hostname hq-rtr.au-team.irpo
int isp 
ip address 172.16.40.14/28
ip nat outside
int 100 
ip address 192.168.1.1/27
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
ip route 0.0.0.0/0 172.16.40.1
ip name-server 77.88.8.8
ip nat pool INTERNET 192.168.1.1-192.168.1.87
ip nat source dynamic inside-to-outside pool INTERNET overload 172.16.40.14
int tunnel.1
ip address 10.10.10.9/30
ip tunnel 172.16.40.14 172.16.50.14 mode gre
ip ospf  authentication-key P@ssw0rd
ip ospf  authentication message-digest
ex
router ospf 1
network 10.10.10.8/30 area 0
network 192.168.1.0/27 area 0
network 192.168.1.64/28 area 0
network 192.168.1.80/29 area 0
passive-interface isp 
passive-interface 100
passive-interface 200
passive-interface 999
area 0 authentication message-digest
ex
do wr
 
3. BR-RTR
en
conf t
hostname br-rtr.au-team.irpo
int isp
ip address 172.16.50.14/28
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
ip route 0.0.0.0/0 172.16.50.1
ip name-server 77.88.8.8
ip nat pool INTERNET 192.168.2.1-192.168.2.30
ip nat source dynamic inside-to-outside pool INTERNET overload 172.16.50.14
int tunnel.1
ip address 10.10.10.10/30
ip tunnel 172.16.50.14 172.16.40.14 mode gre
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
 
4. HQ-SW
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
5. DNS HQ-SRV
hostnamectl hostname hq-srv.au-team.irpo; exec bash
cd /etc/net/ifaces/ens19
echo 192.168.1.2/27 > ipv4address
echo default via 192.168.1.1 > ipv4route
echo nameserver 77.88.8.8 > resolv.conf
systemctl restart network
apt-get update && apt-get install nano bind bind-utils -y
cd /etc/bind/

nano named.conf
#include “/etc/bind/rndc.conf”; - kommentiruyu stroku, ne pishu!

nano options.conf
listen-on { 192.168.1.2; }; - menyayu adres na etot!
//listen-on-v6 { ::1;}; - kommentiruem stroku, ne pishu!
forwarders { 77.88.8.8; }; - raskommentiroval i zapisal adres!
allow-query { any; }; - raskommentiroval i zapisal znachenie!
allow-query-cache { any; }; - raskommentiroval i zapisal znachenie!
allow-recursion { any; }; - raskommentiroval i zapisal znachenie!

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
Ctrl \\ - sochetanie klavish!
localhost
au-team.irpo
A - nazhimayu!
IN	A	192.168.1.2 - menyayu adres na etot!

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
moodle IN	A	172.16.40.1
wiki IN	A	172.16.50.1

nano db.reverse
1	IN	PTR	hq-rtr.au-team.irpo.
65	IN	PTR	hq-rtr.au-team.irpo.
81	IN	PTR	hq-rtr.au-team.irpo.
2	IN	PTR	hq-srv.au-team.irpo.
66	IN	PTR	hq-cli.au-team.irpo.
systemctl restart bind
cd /etc/net/ifaces/{int}

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
 
6. DNS for RTR
en
conf t
no ip name-server 77.88.8.8
ip name-server 192.168.1.2
ip domain-name au-team.irpo
do ping hq-srv
do wr
 
7. DHCP HQ-RTR
ip pool hq 192.168.1.67-192.168.1.78
dhcp-server 1
static ip 192.168.1.66
client-id mac {mac-address hq-cli}
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
 
8.	HQ-CLI
hostnamectl hostname hq-cli.au-team.irpo; exec bash
timedatectl set-timezone Europe/Moscow
ping ya.ru
host hq-srv
 
9.	BR-SRV
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
 
10. time + admin RTR
ntp timezone utc+3
username net_admin
password P@$$word
role admin
ex
do wr
 
11.	Nastrojka uchyotok, pol'zakov, vremeni na obeih SRV
useradd -m sshuser -u 1010 -s /bin/bash
passwd sshuser
P@ssw0rd - dva raza!
usermod -aG wheel sshuser

mcedit /etc/sudoers
WHEEL_USERS ALL=(ALL:sshuser) NOPASSWD: ALL - raskommentiroval i zapisal znachenie!

su - sshuser
sudo vim

nano /etc/openssh/sshd_config
Port 2024 - raskommentiroval i zapisal znachenie!
AllowUsers sshuser - napisal vruchnuyu!
MasAuthTries 2 - raskommentiroval i zapisal znachenie!
Banner /etc/banner.net - raskommentiroval i zapisal znachenie!

nano /etc/banner.net
Authorized Access Only - posle etogo nazhat' enter i uzhe potom sohranit'!

systemctl restart sshd.service
ssh -p 2024 sshuser@localhost
exit

timedatectl set-timezone Europe/Moscow 
Second modul
1.Samba BR-SRV
apt-get update && apt-get install task-samba-dc alterator-{fbi,net-domain} admx-* admc gpui git -y 
systemctl enable --now ahttpd alteratord
domainname au-team.irpo

mcedit /etc/sysconfig/network
HOSTNAME=br-srv.au-team.irpo - menyayu znachenie na eto
rm -rf /etc/samba/smb.conf /var/{lib,cache}/samba
mkdir -p /var/lib/samba/sysvol
samba-tool domain provision --realm=au-team.irpo --domain=au-team --adminpass=’P@ssw0rd’ --dns-backend=BIND9_DLZ --server-role=dc --use-rfc2307
Idyom na klienta nizhe na punkt 2!
git clone https://github.com/Wrage-ru/parse-csv.git
cd parse-csv/
mv example.csv /opt/users.csv
chmod +x create-user.sh
./create-user.sh /opt/users.csv
samba-tool group add hq
for i in $(seq 1 5); do samba-tool user add user$i.hq ‘P@ssw0rd’; done
for i in $(seq 1 5); do samba-tool group addmembers hq user$i.hq; done
admx-msi-setup
samba-tool computer add moodle --ip-address=172.16.40.1 -U Administrator
samba-tool computer add wiki --ip-address=172.16.50.1 -U Administrator
samba-tool computer add HQ-SRV --ip-address=192.168.1.2 -U Administrator
samba-tool computer add mon --ip-address=192.168.1.2 -U Administrator
 
2.	Vvod v domen i nastrojka Samba na HQ-CLI
apt-get update && apt-get install admx-* admc gpui sudo gpupdate -y
Perekhodim v Firefox po adresu 192.168.2.2:8080, dolzhen otkryt'sya centr upravleniya sistemoj.
Nazhimaem Nastrojka
 

Rezhim eksperta - Primenit'
 

Perekhodim v razdel Veb-interfejs
 

Menyaem port s 8080 na 8081 - Primenit' - Perezapustit' HTTP-server
 
Perekhodim v razdel Domen, menyaem adres na 192.168.2.2, parol' admina - P@ssw0rd, Primenit' 
 

V sluchae uspekha, dolzhny pomenyat'sya znacheniya tekushchego sostoyaniya:
 

V parametrah provodnogo soedineniya ukazyvaem dop. servery DNS - 192.168.2.2, potom vklyuchaem i otklyuchaem podderzhku seti
 
Vozvrashchaemsya v terminal
acc
V razdele Pol'zovateli nazhimaem na Autentifikaciya 
 

Dopisyvaem rabochuyu gruppu au-team, Primenit'
 

Uspeshno vypolnenie
 

Vozvrashchaemsya na BR-SRV vyshe k git clone!
Zahodim pod Administrator, parol' P@ssw0rd
su -
admx-msi-setup
roleadd hq wheel

mcedit /etc/sudoers
User_Alias		WHEEL_USERS = %wheel, %AU-TEAM\\\\hq - dopisal!
Cmnd_Alias		SHELLCMD = /usr/bin/id, /bin/cat, /bin/grep - napisal novuyu strochku!
WHEEL_USERS ALL=(ALL:ALL) SHELLCMD - raskommentiroval i pomenyal s ALL na SHELLCMD!

Vyhodim iz ruta
kinit
admc

Raskryvaem Ob"ekty gruppovoj politiki, PKM po au-team.irpo - Sozdat' politiku i svyazat' s etim podrazdeleniem
 

Nazyvaem sudoers
 

Stavim galochku na Prinuditel'no
 

PKM po sudoers - Edit
 

Perekhodim po puti Komp'yuter - Administrativnye shablony - Samba - Nastrojki Unix - Upravleniem razresheniyami Sudo, sostoyanie politiki - Vklyucheno, Redaktirovat'
 

Dobavlyaem tri polya, propisyvaem /usr/bin/id v pervom, /bin/cat vo vtorom, /bin/grep v tret'em, potom nazhimaem OK
 

Nazhimaem OK v pravom nizhnem uglu, zakryvaem okna, vozvrashchaemsya v terminal
gpupdate -f
Vyhodim iz tekushchego pol'zovatelya
Zahodim pod pol'zovatelem user3.hq - Parol' P@ssw0rd
Zahodim v terminal
sudo id
sudo cat /root/.bashrc
 
3.	Konfiguraciya fajlovogo hranilishcha na HQ-SRV
lsblk - необходимы три диска для raid (sdb, sdc, sdd)
mdadm -C /dev/md0 -l 5 -n 3 /dev/sd{b,c,d}
lsblk - proveryaem, chto diski sdb, sdc, sdd v raid5
mkfs.ext4 /dev/md0
echo DEVICE partitions >> /etc/mdadm.conf
mdadm --detail --scan >> /etc/mdadm.conf
mkdir /raid5

mcedit /etc/fstab
/dev/md0	/raid5	ext4	defaults	0	0

mount -a
df -h - ubedit'sya, что md0 в raid5

apt-get install nfs-{server,utils} -y
mkdir /raid5/nfs
chmod 777 /raid5/nfs/

mcedit /etc/exports
#/srv/public -ro,insecure,nosubtree_check,fsid=1 * - kommentiruyu stroku!
/raid5/nfs 192.168.1.64/28(rw,no_subtree_check,no_root_squash)

exportfs -arv
systemctl enable --now nfs-server.service
 
4.	Nastrojka avtomontirovaniya na HQ-CLI
mkdir /mnt/nfs
chmod 777 /mnt/nfs

mcedit /etc/fstab
192.168.1.2:/raid5/nfs	/mnt/nfs	nfs	defaults	0	0

mount -a
df -h - ubedit'sya, chto otobrazhaetsya adres hq-srv
 
5.	Nastrojka chrony-servera na ISP
apt-get install chrony -y

nano /etc/chrony.conf
pool 0.ru.pool.ntp.org iburst - dopisal!
local stratum 5
allow 0.0.0.0/0

systemctl restart chronyd
systemctl enable --now chronyd
chronyc clients - vypolnit' komandu posle nastrojki klientov nizhe! dolzhny byt' klienty 172.16.4.14 i 172.16.5.14, eto normal'no!
 
6.	Nastrojka ntp-klienta na obeih RTR
en
conf t
ntp server 172.16.40.1 - tol'ko na HQ-RTR
ntp server 172.16.50.1 - tol'ko na BR-RTR
do wr
 
7.	Nastrojka chrony-klienta na obeih SRV i HQ-CLI
mcedit /etc/chrony.conf
pool 172.16.40.1 iburst - tol'ko na hq-srv i hq-cli
pool 172.16.50.1 iburst - tol'ko na br-srv

systemctl restart chronyd
systemctl enable --now chronyd
chronyc sources - ubedit'sya, chto otobrazilsya server chrony i ne zabud' proverit' klientov na ISP!
 
8.	Nastrojka ssh na HQ-CLI dlya ansible
mcedit /etc/openssh/sshd_config
AllowUsers sysadmin - napisal vruchnuyu!
Port 2024 - raskommentiroval i pomenyal znachenie!
MasAuthTries 2 - raskommentiroval i pomenyal znachenie!
PunkeyAuthentication yes - raskommentiroval!
PasswordAuthentication yes - raskommentiroval!

systemctl restart sshd
systemctl enable --now sshd
 
9.	 ansible for BR-SRV
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
interpreter_python = /usr/bin/python3 - napisal vruchnuyu!
host_key_checking = False - raskommentiroval!

ansible -m ping all - ubedit'sya, chto u vsekh chetyryoh ustrojstv zelyonyj cvet i pong!
 
10.	Nastrojka Docker na BR-SRV
apt-get install docker-ce docker-compose -y
Poka ustanavlivaetsya, idyom na HQ-CLI nizhe i nastraivaem tam, posle ustanovki pishem tut!
systemctl enable --now docker.socket docker.service
Vozvrashchaemsya na HQ-CLI!

 
11.	Nastrojka HQ-CLI dlya Docker
Zapuskaem Firefox, perekhodim po adresu hub.docker.com, ishchem v poiske mediawiki, vybiraem repozitorij s oranzhevym kol'com, nizhe ishchem primer koda docker-compose.yml

Zapuskaem terminal
ssh -p 2024 sshuser@192.168.2.2
su -

mcedit wiki.yml
Kopiruem syuda tot samyj primer koda na sajte
services:
  wiki:  - udalil chast' slova media!
    image: mediawiki
    restart: always
    ports:
      - 8080:80
    links:
      - mariadb  - zamenil na eto!
    volumes:
      - images:/var/www/html/images
      # - ./LocalSettings.php:/var/www/html/LocalSettings.php
  mariadb: - zamenil na eto!
    image: mariadb
    restart: always
    environment:
      MYSQL_DATABASE: mediawiki - zamenil na eto!
      MYSQL_USER: wiki - zamenil na eto!
      MYSQL_PASSWORD: WikiP@ssw0rd - zamenil na eto!
      MYSQL_RANDOM_ROOT_PASSWORD: \'yes\'
    volumes:
      - db:/var/lib/mysql

volumes:
  images:
  db:

Vozvrashchaemsya na BR-SRV i zhdem poka ustanovitsya doker!
docker compose -f wiki.yml up -d - zhdyom poka vse zapustitsya!

Zahodim v Firefox i perekhodim po adresu 192.168.2.2:8080
Nazhimaem na set up the wiki
 

Dalee
 

Listaem vniz - Dalee
 

Pishem v strochkah: host bazy dannyh: mariadb, imya BD - mediawiki, imya pol'zovatelya BD - wiki, parol' BD - WikiP@ssw0rd, nazhimaem Dalee
 

Dalee
 

Nazvanie viki - wiki, imya uchastnika - wiki, parol' - WikiP@ssw0rd, snimaem galochku s «Podelit'sya svedeniyami...», vybrat' «Hvatit uzhe, prosto…», Dalee
 

Dalee 
 

Dalee
 

U nas zagruzitsya fajl LocalSettings.php
 

Otkryvaem terminal v papke Zagruzki
 

scp -P 2024 LocalSettings.php sshuser@192.168.2.2:/home/sshuser 

Tak zhe na kliente otkryvaem terminal, gde u nas uzhe est' podklyuchenie k BR-SRV
mv /home/sshsuser/LocalSettings.php .

mcedit wiki.yml
    - ./LocalSettings.php:/var/www/html/LocalSettings.php - raskommentiroval stroku!

docker compose -f wiki.yml down
docker compose -f wiki.yml up -d

Zahodim v Firefox i perekhodim po adresu 192.168.2.2:8080, vidim, chto glavnaya stranica pomenyalas', nazhimaem Vojti v pravom verhnem uglu

Avtorizuemsya
 
 
12.	Nastrojka staticheskoj translyacii portov na HQ-RTR
en
conf t
ip nat destination static tcp 172.16.40.14 2024 192.168.1.2 2024 hairpin
ip nat source static tcp 192.168.1.2 2024 172.16.40.14 2024
ip nat destination static tcp 172.16.40.14 80 192.168.1.2 80 hairpin
ip nat source static tcp 192.168.1.2 80 172.16.40.14 80
do wr
 
13.	Nastrojka staticheskoj translyacii portov na BR-RTR
en
conf t
ip nat destination static tcp 172.16.50.14 2024 192.168.2.2 2024 hairpin
ip nat source static tcp 192.168.2.2 2024 172.16.50.14 2024
ip nat destination static tcp 172.16.50.14 80 192.168.2.2 8080 hairpin
ip nat source static tcp 192.168.2.2 8080 172.16.50.14 80
do wr
 
14.	Proverka raboty translyacii portov na HQ-CLI i BR-SRV
ssh -p 2024 sshuser@172.16.40.14
exit
ssh -p 2024 sshuser@172.16.50.14 
exit
Zahodim v Firefox po adresu 172.16.50.14 i dolzhno byt' perenapravlenie na 192.168.2.2:8080
 
15.	Nastrojka moodle na HQ-SRV
apt-get install deploy -y

mcedit /usr/share/deploy/moodle/tasks/main.yml
F4 - zamenyaem moodle1 na moodledb dlya vsekh
Eshche raz F4 - zamenyaem moodleuser  na moodle dlya vsekh
-name: generate password for Moodle
 shell: echo ‘P@ssw0rd’ - zamenil na eto znachenie!

deploy moodle
Poka deploy delaet progon, idem nizhe na punkt 16 stavit' brauzer i posle togo kak deploy sdelaet progon, idyom donastraivat' moodle na HQ-CLI
 
16.	Ustanovka Yandeks Brauzera dlya Organizacij na HQ-CLI
su -
apt-get install yandex-browser -y
*Lichnaya zametka*
Dal'she neskol'ko putej: mozhno zapomnit' moyu sokrashchennuyu ssylku nizhe i skachat' fajl, libo zahodit' v svoj akkaunt na tachke. Navernyaka pervyj variant kazhetsya vsem predpochtitel'nej, poetomu skachivaem otsyuda:
goo.su/pHFVM
Na 19 maya 2025 versiya Yandeks Brauzera dlya Organizacij - 25.2.1
Zapuskaem skachennyj fajl
 
17.	Donastrojka moodle na HQ-CLI
Zapuskaem brauzer i perekhodim po adresu 192.168.1.2/moodle
V pravom verhnem uglu nazhimaem Vhod

Login - admin, parol' - P@ssw0rd
 

Adres elektronnoj pochty - moodle@au-team.irpo
 

Nizhe nazhimaem knopku Obnovit' profil'
 

V pravom verhnem uglu vklyuchaem rezhim redaktirovaniya
 

Perekhodim v razdel Nastrojki i menyaem znachenie Polnoe nazvanie sajta na svoj nomer rabochego mesto. U Naumca eto 1, u nas v zavisimosti ot togo na kakoe my syadem na demoekzamene 

Listaem nizhe i nazhimaem Sohranit' izmeneniya
 

Vyklyuchaem rezhim redaktirovaniya i idem v razdel V nachalo
 
 
18.	Nastrojka veb-servera Nginx na ISP
apt-get install nginx -y

nano /etc/nginx/sites-available.d/default.conf
upstream moodle.au-team.irpo {
server 172.16.40.14;
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
server 172.16.50.14:80;
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
19.	Izmenenie adresa wiki dlya Nginx na BR-SRV
cd ~
nano LocalSettings.php
$wgServer = http://wiki.au-team.irpo:8080; - pomenyal znachenie!

docker compose -f wiki.yml down
docker compose -f wiki.yml up -d
 
20.	Izmenenie adresa moodle dlya Nginx na HQ-SRV
nano /var/www/webapps/moodle/config.php
$CFG->wwwroot = ‘http://moodle.au-team.irpo/moodle’; - pomenyal znachenie!

nano /etc/httpd2/conf/sites-enabled/000-default.conf
Listaem v samyj konec!
#RewriteEngine On - zakommentiroval!
#RewriteCond %{HTTPS} !=on - zakommentiroval!
#RewriteRule ^/(.*) https://%{HTTPS_HOST}/$1 [R,L] - zakommentiroval!

systemctl restart httpd2
 
Tretij modul'
1.	Migraciya kontrollera domena
Netu
 
2.	Nastrojka centra sertifikacii
Netu
 
3.	Shifrovanie IP-Tunnelya
Netu
 
4.	Nastrojka mezhsetevogo ekrana na HQ-RTR
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
 
5.	Nastrojka mezhsetevogo ekrana na BR-RTR
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
 
6.	Nastrojka print-servera CUPS na HQ-SRV
apt-get install cups cups-pdf -y
systemctl enable --now cups

nano /etc/cups/cupsd.conf
Vezde gde est' Location dopisat' Allow all
 

systemctl restart cups
 
7.	Donastrojka print-servera CUPS na HQ-CLI
su -
lpadmin -x Cups-PDF
lpadmin -p CUPS -E -v ipp://hq-srv.au-team.irpo:631/printers/Cups-PDF -m everywhere
lpadmin -d CUPS
lpstat -p
Pechataem lyuboj dok, perekhodim po adresu printera https://hq-srv.au-team.irpo:631, Printery, Cups-PDF, Pokazat' vse zadaniya (dolzhno byt' zadanie so statusom \"zaversheno\")
 
8.	Nastrojka logirovaniya
Netu
 
9.	Nastrojka monitoringa na HQ-SRV
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
 
10.	Nastrojka agenta monitoringa na BR-SRV
mcedit /etc/zabbix/zabbix_agentd.conf
Server=0.0.0.0/0
ServerActive=192.168.1.2
Hostname=br-srv.au-team.irpo

systemctl enable --now zabbix_agentd
 
11.	Nastrojka veb-interfejsa Zabbix na HQ-CLI
Perekhodim v brauzere po adresu mon.au-team.irpo:8080
Login, parol': Admin, zabbix
Users > Authentication i snimaem galochku  Avoid easy-to-guess password, sohranyaem
User settings > Profile menyaem parol' na P@ssw0rd
Perekhodim Monitoring > Hosts, najimaem na Zabbix Server, menyaem adres na 192.168.1.2, Update
Tut je v pravom verhnem uglu Create host
Ukazyvaem hostname - BR-SRV, templates - linux by zabbix agent 
Vybiraem gruppu linux servers i ukazyvaem adres agent - 192.168.2.2
Dashbor > edit 
Udalyaem ne nuzhnye vidzhity i dobavlyaem vidzhity dlya hostov
Tip grafik
Nizhe - host - nuzhnyj host , ram % , cpu utilization, fs space used in %
dobavlyaem dlya kazhdoj mashiny i sohranyaem izmeneniya dashborda!
 
12.	Nastrojka inventarizacii cherez ansible na BR-SRV
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
        dest: \"/etc/ansible/PC_INFO/{{ ansible_hostname }}.yml\"
        content: |
            Imya komp'yutera: \'{{ ansible_hostname }}\'
            IP-adres komp'yutera: \'{{ ansible_default_ipv4.address }}\'

ansible-playbook /etc/ansible/playbook.yml - esli tak ne rabotaet, to dopisyvaem -K
ls /etc/ansible/PC_INFO/
cat /etc/ansible/PC_INFO/kakoj-to fajl.yml
 
13.	Mekhanizm rezervnogo kopirovaniya cherez ansible na BR-SRV
Poka netu
