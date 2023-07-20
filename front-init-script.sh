#!/bin/bash 
git clone https://github.com/LabregoPT/movie-analyst-front.git /home/ubuntu/ui;
apt -y update;
apt -y upgrade;
apt -y install npm;
npm install --prefix /home/ubuntu/ui;
node /home/ubuntu/ui/server;
node /home/ubuntu/ui/admin-server;