sudo apt-get update
sudo apt-get install apache2 -y
sudo systemctl enable apache2
sudo systemctl start apache2
sudo apt-get install mysql-client mysql-server -y
sudo apt-get install php7.0 php7.0-mysql libapache2-mod-php7.0 php7.0-cli php7.0-cgi php7.0-gd -y
sudo wget https://wordpress.org/latest.zip
sudo apt-get install unzip -y
sudo unzip latest.zip
sudo rsync -av wordpress/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo cp /wp-config.php /var/www/html/wp-config.php
sudo systemctl restart apache2
sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-5.5.3-amd64.deb
sudo dpkg -i filebeat-5.5.3-amd64.deb
sudo cd /
sudo cd /etc/filebeat/
sudo rm -rf filebeat.yml
sudo cd /
sudo cp /filebeat.yml /etc/filebeat/filebeat.yml
sudo /etc/init.d/filebeat start
sudo service filebeat start
