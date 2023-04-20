app_user=roboshop
script=$(realpath "$0")
script_path=$(dirname "$script")
log_file=/tmp/roboshop.log
# rm -f $log_file


func_print_head() {
  echo -e "\e[35m>>>>>>>>> $1 <<<<<<<<\e[0m"
  echo -e "\e[35m>>>>>>>>> $1 <<<<<<<<\e[0m" &>>$log_file
}

func_stat_check() {
  if [ $1 -eq 0 ]; then
    echo -e "\e[32mSUCCESS\e[0m"
  else
    echo -e "\e[31mFAILURE\e[0m"
    echo "Refer the log file /tmp/roboshop.log for more information"
    exit 1
  fi
}

func_schema_setup() {
  if [ "$schema_setup" == "mongo" ]; then
    func_print_head "Copy MongoDB repo"
    cp ${script_path}/mongo.repo /etc/yum.repos.d/mongo.repo &>>$log_file
    func_stat_check $?

    func_print_head "Install MongoDB Client"
    yum install mongodb-org-shell -y &>>$log_file
    func_stat_check $?

    func_print_head "Load Schema"
    mongo --host mongodb-dev.rdevopsb72.online </app/schema/${component}.js &>>$log_file
    func_stat_check $?
  fi
  if [ "${schema_setup}" == "mysql" ]; then
    func_print_head "Install MySQL Client"
    yum install mysql -y &>>$log_file
    func_stat_check $?

    func_print_head "Load Schema"
    mysql -h mysql-dev.rdevopsb72.online -uroot -p${mysql_root_password} < /app/schema/shipping.sql &>>$log_file
    func_stat_check $?
  fi
}

func_app_prereq() {
  func_print_head "Create Application User"
  id ${app_user} &>>/tmp/roboshop.log
  if [ $? -ne 0 ]; then
    useradd ${app_user} &>>/tmp/roboshop.log
  fi
  func_stat_check $?

  func_print_head "Create Application Directory"
  rm -rf /app &>>$log_file
  mkdir /app &>>$log_file
  func_stat_check $?

  func_print_head "Download Application Content"
  curl -L -o /tmp/${component}.zip https://roboshop-artifacts.s3.amazonaws.com/${component}.zip &>>$log_file
  func_stat_check $?

  func_print_head "Extract Application Content"
  cd /app
  unzip /tmp/${component}.zip &>>$log_file
  func_stat_check $?
}

func_systemd_setup() {
  func_print_head "Setup SystemD Service"
  cp ${script_path}/${component}.service /etc/systemd/system/${component}.service &>>$log_file
  func_stat_check $?

  func_print_head "Start ${component} Service"
  systemctl daemon-reload &>>$log_file
  systemctl enable ${component} &>>$log_file
  systemctl restart ${component} &>>$log_file
  func_stat_check $?
}

func_nodejs() {
  func_print_head "Configuring NodeJS repos"
  curl -sL https://rpm.nodesource.com/setup_lts.x | bash &>>$log_file
  func_stat_check $?

  func_print_head "Install NodeJS"
  yum install nodejs -y &>>$log_file
  func_stat_check $?

  func_app_prereq

  func_print_head "Install NodeJS Dependencies"
  npm install &>>$log_file
  func_stat_check $?

  func_schema_setup
  func_systemd_setup
}

func_java() {
  func_print_head "Install Maven"
  yum install maven -y &>>$log_file
  func_stat_check $?
  
  func_app_prereq
  
  func_print_head "Download Maven Dependencies"
  mvn clean package &>>$log_file
  func_stat_check $?
  mv target/${component}-1.0.jar ${component}.jar &>>$log_file
  
  func_schema_setup
  func_systemd_setup
}


func_python() {
  func_print_head "Install Python"
  yum install python36 gcc python3-devel -y &>>$log_file
  func_stat_check $?

  func_app_prereq

  func_print_head "Install Python Dependencies"
  pip3.6 install -r requirements.txt &>>$log_file
  func_stat_check $?

  func_print_head "Update Passwords in System Service file"
  sed -i -e "s|rabbitmq_appuser_password|${rabbitmq_appuser_password}|" ${script_path}/payment.service &>>$log_file
  func_stat_check $?

  func_systemd_setup

}