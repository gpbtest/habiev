# testapp

## Installation
```sh
git clone https://gitlab.com/habiev/testapp.git

sudo cpan install Data::UUID
sudo cpan install Mojolicious::Lite
sudo cpan install JSON
sudo cpan install DBI
#sudo cpan install DBD::mysql
sudo apt-get install libdbd-mysql-perl


sudo docker run --detach --name testapp-mariadb -p 3306:3306 --env MARIADB_USER=example-user --env MARIADB_PASSWORD=my_cool_secret --env MARIADB_ROOT_PASSWORD=zmWZhytx2302  mariadb:latest
sudo docker exec -it testapp-mariadb mysql -u root -pzmWZhytx2302 -e "create database example_database"; 
```

## Start
```sh
cd testapp/
perl server.pl

Init DB success!
Start App!
Create table message
Create table log
Create table upload_files
[2023-05-11 09:57:16.32270] [41216] [info] Listening at "http://*:8080"
Web application available at http://127.0.0.1:8080

```

## Demo
Demo website [habiev.com:8080](http://habiev.com:8080/)