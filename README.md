# weight-server
## Set Pi Password:
ssh into the PI and type:
`passwd`
enter the required password

## update PI:
`sudo apt-get update`
`sudo apt-get upgrade --fix-missing -y`
`sudo reboot`

## rename the PI
`sudo raspi-config`


## setup the LCD 
`git clone https://github.com/goodtft/LCD-show.git`
`chmod -R 755 LCD-show`
`cd LCD-show/`
`sudo ./LCD35-show`
`sudo reboot`

## setup a screen saver
`sudo apt install xscreensaver`

## install ruby 
sudo apt update
sudo apt install snapd
sudo reboot
sudo snap install core
sudo snap install ruby --classic

## gems required:
`gem install net-ping pubnub rest-client --no-doc`

# setup the git repo
`git clone https://github.com/BioData/weight-server.git`



pub-c-78683cc0-1c65-4dac-9e5b-9e0a7d29f920
sub-c-69ae6d54-af8d-11ec-ab44-ba44ac190480
{"flow_id":"171", "token":"498fc2cab8102512115b3"}
https://pace-flow.labguru.com/flows/27/flow_runs/external_trigger.json?token=a52b5afafdb5a4ae0550d