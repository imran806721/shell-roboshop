#!/bin/bash

LOGS_DIR="/var/log/roboshop"
LOGS_FILE="LOGS_DIR/$0.log"
USERID=$(id -u)
R="\e[31m"
G="\e[32m
Y="\e[33m"
TIMESTAMP=$(date "+%y-%m-%d %H:%M:%S")


if [ $USERID -ne 0 ]; then
    echo -e "$TIMESTAMP [ERROR] $R Please run this script with root access $N" | tee -a $LOGS_FILE
    exit 1
fi

VALIDATE(){
      if [ $1 -ne 0 ]; then
           echo -e "$TIMESTAMP [ERROR] $2 ... $R FAILURE $N" | tee -a $LOGS_FILE
           exit1
      else
           echo -e "$TIMESTAMP [INFO]  $2 ... $g SUCCESS $N" | tee -a $LOGS_FILE
      fi
}   

cp mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Adding Mongo repo"

# dnf install mongodb-org -y &>> $LOGS_FILE
# VALIDATE $? "Installing Mongodb"

# systemctl enable --now mongod
# VALIDATE $? "Starting ans Enablig MongoDB"

# sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
# VALIDATE $? "Allowing remote connections to MongoDB"

# systemctl restart mongod
# VALIDATE $? "Restarting MongoDB"
