script_path=$(dirname $0)
source ${script_path}/common.sh

echo -e "\e[36m>>>>>>>>> Install Maven <<<<<<<<\e[0m"
yum install maven -y

echo -e "\e[36m>>>>>>>>> Create App User <<<<<<<<\e[0m"
useradd ${app_user}

echo -e "\e[36m>>>>>>>>> Create App Directory <<<<<<<<\e[0m"
rm -rf /app
mkdir /app

echo -e "\e[36m>>>>>>>>> Download App Content <<<<<<<<\e[0m"
curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping.zip

echo -e "\e[36m>>>>>>>>> Extract App Content <<<<<<<<\e[0m"
cd /app
unzip /tmp/shipping.zip

echo -e "\e[36m>>>>>>>>> Download Maven Dependencies <<<<<<<<\e[0m"
mvn clean package
mv target/shipping-1.0.jar shipping.jar

echo -e "\e[36m>>>>>>>>> Install MySQL <<<<<<<<\e[0m"
yum install mysql -y

echo -e "\e[36m>>>>>>>>> Load Schema <<<<<<<<\e[0m"
mysql -h mysql-dev.rdevopsb72.online -uroot -pRoboShop@1 < /app/schema/shipping.sql

echo -e "\e[36m>>>>>>>>> Setup SystemD Service <<<<<<<<\e[0m"
cp ${script_path}/shipping.service /etc/systemd/system/shipping.service

echo -e "\e[36m>>>>>>>>> Start Shipping Service <<<<<<<<\e[0m"
systemctl daemon-reload
systemctl enable shipping
systemctl restart shipping
