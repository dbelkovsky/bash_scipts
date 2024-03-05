#!/bin/bash

#Руководство по установке OSM-tile сервера на убунту 22.04 
#в убунту и дебиане все можно  ставить из коробки, ничего не надо собирать, компилировать. все уже готово
# все выполняется под SUDO
#vars(переменные)
ipaddr=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')
#Установим необходимые пакеты:
apt update && apt upgrade
apt install -y screen locate libapache2-mod-tile renderd git tar unzip wget bzip2 apache2 lua5.1 mapnik-utils python3-mapnik python3-psycopg2 python3-yaml gdal-bin npm fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-unifont fonts-hanazono postgresql postgresql-contrib postgis postgresql-15-postgis-3 postgresql-15-postgis-3-scripts osm2pgsql net-tools curl

#создадим системного пользователя для работы рендеринга
adduser --system --group osm #имя может быть произвольным, но нне отличимым от того, которого мы создадим позже для БД
#Добавим АСL и доступ нашему пользователю в нужную директорию
apt install acl
sudo setfacl -R -m  u:postgres:rwx /home/osm/ 
#Далее все манипуляции будем выполнять в директори нашего пользователя
cd /home/osm/
#создадим пользователя и БД
sudo -u postgres -i
#создаем пользователя
createuser osm # помним про пользователя и его имя должно быть одинаковым как и системный пользователь
#сознаем БД
createdb -E UTF8 -O osm gis #gis это и есть имя БД
#создаем экстеншены в БД
psql -c "CREATE EXTENSION hstore;" -d gis
psql -c "CREATE EXTENSION postgis;" -d gis
psql -c "ALTER TABLE geometry_columns OWNER TO osm;" -d gis
psql -c "ALTER TABLE spatial_ref_sys OWNER TO osm;" -d gis
exit

###MAPNIK
python3
import mapnik  
quit()
#ставим carto
git clone https://github.com/gravitystorm/openstreetmap-carto
cd openstreetmap-carto/
npm install -g carto
carto -v
carto project.mml > mapnik.xml

#скачиваем карту в формате osm.pbf на примере Калининградской области
wget https://download.geofabrik.de/russia/kaliningrad-latest.osm.pbf
#производим добавление карты в БД
sudo -u osm osm2pgsql -d gis --create --slim  -G --hstore --tag-transform-script ~osm/openstreetmap-carto/openstreetmap-carto.lua -C 2500 --number-processes 1 -S ~osm/openstreetmap-carto/openstreetmap-carto.style ~osm/openstreetmap-carto/kaliningrad-latest.osm.pbf
#индексируем
sudo -u osm psql -d gis -f indexes.sql
sudo -u osm scripts/get-external-data.py
#устанавливаем шрифты
scripts/get-fonts.sh

#правим конфиг для рендерД
cat << EOF >> /etc/renderd.conf
[default]
URI=/osm/
TILEDIR=/var/cache/renderd/tiles
XML=/home/osm/openstreetmap-carto/mapnik.xml
HOST=localhost
TILESIZE=256
MAXZOOM=20
EOF

#Добавлем сообщения об ошибках, ВАЖНО!
cat << EOF >> /usr/lib/systemd/system/renderd.service
Environment=G_MESSAGES_DEBUG=all
EOF

#Создаем директорию для юнита и конфига
mkdir /etc/systemd/system/renderd.service.d/
touch /etc/systemd/system/renderd.service.d/custom.conf
cat << EOF > /etc/systemd/system/renderd.service.d/custom.conf
[Service]
User=osm
EOF
#Меняем права на директториях
sudo chown osm:osm /run/renderd/ -R
sudo chown osm:osm /var/cache/renderd/tiles/ -R
#перезагружаем сервисы
systemctl daemon-reload
systemctl restart renderd
systemctl restart apache2
/etc/init.d/apache2 restart
#добавляем модуль mod_tile
a2enmod tile
#Прописываем конфиг для apache2
cat << EOF >> /etc/apache2/sites-available/tileserver_site.conf
<VirtualHost *:80>
    ServerName $ipaddr 
    LogLevel info
    Include /etc/apache2/conf-available/renderd.conf

</VirtualHost>
EOF
#
a2ensite tileserver_site.conf
systemctl restart apache2
#Настройка отображения карты
cd /var/www/html/
wget https://github.com/openlayers/openlayers/releases/download/v5.3.0/v5.3.0.zip
unzip v5.3.0.zip
#ВАЖНО ТАКЖЕ ЗАРАНЕЕ В СКРИПТЕ УКАЗАТЬ IP СЕРВЕРА,
cat << EOF > index.html
<!DOCTYPE html>
<html style="height:100%;margin:0;padding:0;">
<title>Leaflet page with OSM render server selection</title>
<meta charset="utf-8">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.3/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet@1.3/dist/leaflet.js"></script>
<script src="https://unpkg.com/leaflet-hash@0.2.1/leaflet-hash.js"></script>
<style type="text/css">
.leaflet-tile-container { pointer-events: auto; }
</style>
</head>
<body style="height:100%;margin:0;padding:0;">
<div id="map" style="height:100%"></div>
<script>
//<![CDATA[
var map = L.map('map').setView([63, 100], 3);

L.tileLayer('http://$ipaddr/osm/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
}).addTo(map);

var hash = L.hash(map)
//]]>
</script>
</body>
</html>
EOF
#
systemctl restart apache2
wget http://cdn.leafletjs.com/leaflet/v1.7.1/leaflet.zip
unzip leaflet.zip
systemctl restart apache2
systemctl restart renderd

echo "НАСТРОЙКА ЗАВЕРШЕНА"
