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
`gem install bundler net-ping pubnub rest-client --no-doc`

# setup the git repo
`git config --global credential.helper store`
`git clone https://github.com/BioData/weight-server.git`

# setup rc.local 
