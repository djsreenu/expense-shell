#!/bin/bash
LOG_FOLDER="/var/log/expense"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
TIME_STAMP=$(date +%Y-%m-%d-%H-%M-%S)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME-$TIME_STAMP.log"
mkdir -p $LOG_FOLDER

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
N="\e[0m"
Y="\e[33m"

CHECK_ROOT(){
    if [ $USERID -ne 0 ]
    then
        echo -e " $R Please run this script with root priveleges $N" | tee -a $LOG_FILE
        exit 1
    fi
}

VALIDATE(){
    if [ $1 -ne 0 ]
    then
        echo -e "$2 is...$R FAILED $N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "$2 is... $G SUCCESS $N"  | tee -a $LOG_FILE
    fi
}

echo "Script started execution at : $(date)" | tee -a $LOG_FILE

CHECK_ROOT

dnf module disable nodejs -y &>>LOG_FILE
VALIDATE $? "disable nodejs"

dnf module enable nodejs:20 -y &>>LOG_FILE
VALIDATE $? "Enable nodejs"

dnf install nodejs -y &>>LOG_FILE
VALIDATE $? "Install nodejs"

id expense &>>LOG_FILE
if [ $? -ne 0 ]
then
    echo -e "Expense user is not exist $G creating .. $N"
    useradd expense  &>>$LOG_FILE
    VALIDATE $? "Creating Expense user"
else
    echo -e "Expnese user already exists.. $Y SKIPPING...$N"

Mkdir -p /app &>>LOG_FILE
VALIDATE $? "Creating app folder"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOG_FILE
VALIDATE $? "Dowloading backend application code"

cd /app
rm -rf /app/*
unzip /tmp/backend.zip &>>LOG_FILE
VALIDATE $? "Extracting application code"

npm install &>>LOG_FILE
VALIDATE $? "Install dependency"
cp /home/ec2-user/expense-shell/backend.service /etc/systemd/system/backend.service

#load the data before running backend
dnf install mysql -y &>>LOG_FILE
VALIDATE $? "Installing MySQL client"

mysql -h 172.31.25.78 -uroot -pExpenseApp@1 < /app/schema/backend.sql &>>$LOG_FILE
VALIDATE $? "Schema loading"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Daemon reload"

systemctl enable backend &>>$LOG_FILE
VALIDATE $? "Enabled backend"

systemctl restart backend &>>$LOG_FILE
VALIDATE $? "Restarted Backend"