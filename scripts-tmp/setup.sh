####################
# Minecraft on EC2 #
####################

cd ~
chmod +x bin/*

echo 'export PATH=~/bin:$PATH' >> ~/.bashrc

source ~/.bashrc

# install dependencies
echo "Installing required tools..."
sudo yum -y install make gcc screen > setup.log
echo "Done!"

# Enable multiuser support for screen
mv screenrc .screenrc
sudo chmod +s /usr/bin/screen
sudo chmod 755 /var/run/screen

# install c10t (mapping library)
echo "Downloading c10t (mapping library)..."
wget --quiet http://toolchain.eu/minecraft/c10t/releases/c10t-1.9-linux-x86.tar.gz
tar -xf c10t-1.9-linux-x86.tar.gz && cp c10t-1.9-linux-x86/c10t ~/bin
echo "Done!"

while [[ $BACKUP_MODE != 'local' && $BACKUP_MODE != 's3' ]]; do
  echo "What backup method would you like to use? Options are 's3' or 'local' (default)."
  read BACKUP_MODE
  if [ ${#BACKUP_MODE} -eq 0 ]; then
    BACKUP_MODE='local'
  fi
done
echo "Using $BACKUP_MODE mode for backups."

if [[ $BACKUP_MODE = 's3' ]]; then
  echo "Enter the name of your bucket on S3 (you can edit it later in ~/bin/mc):"
  read BUCKET_NAME
fi

sed --in-place -e "s/{{BUCKET_NAME}}/$BUCKET_NAME/" ~/bin/mc
sed --in-place -e "s/{{BACKUP_MODE}}/$BACKUP_MODE/" ~/bin/mc

# install and configure s3cmd
echo "Downloading S3 command-line tools..."
wget --quiet http://downloads.sourceforge.net/project/s3tools/s3cmd/1.0.1/s3cmd-1.0.1.tar.gz
tar -xf s3cmd-1.0.1.tar.gz && cd s3cmd-1.0.1 && sudo python setup.py install >> setup.log
echo "Done!"

if [[ $BACKUP_MODE = 's3' ]]; then
  s3cmd --configure
fi

# install No-IP update client
echo "Downloading No-IP dynamic DNS update client..."
wget --quiet https://www.no-ip.com/client/linux/noip-duc-linux.tar.gz
tar -xf noip-duc-linux.tar.gz
cd noip-2.1.9-1
cp ~/scripts-tmp/noip-Makefile ./Makefile
make --silent && sudo make --silent install >> setup.log && cd .. && rm -r noip-2.1.9-1 && rm noip-duc-linux.tar.gz
echo "Done!"

# enter No-IP details in next step
sudo /usr/local/bin/noip2 -C

# the result from running this command should be 3
# grep initdefault /etc/inittab | awk -F: '{print $2}'

# No-IP startup script
sudo cp ~/scripts-tmp/noip-startup.sh /etc/init.d/noip
sudo chmod +x /etc/init.d/noip
# link to script in proper rc directory (rc3.d)
sudo ln -s /etc/init.d/noip /etc/rc3.d/S99noip

# Start No-IP update client
sudo /etc/init.d/noip start

# get Minecraft
mkdir ~/minecraft
cd ~/minecraft
echo "Downloading Minecraft server..."
wget --quiet https://s3.amazonaws.com/MinecraftDownload/launcher/minecraft_server.jar
echo "Done!"

echo "Enter your Minecraft username to be added to the ops list:"
read PLAYER_NAME
echo $PLAYER_NAME > ~/minecraft/ops.txt

# Minecraft startup script (just like the No-IP one)
sudo cp ~/scripts-tmp/minecraft-startup.sh /etc/init.d/minecraft
sudo chmod +x /etc/init.d/minecraft
sudo ln -s /etc/init.d/minecraft /etc/rc3.d/S99minecraft

# register shutdown script in crontab
while [[ $IDLE_SHUTDOWN != 'n' && $IDLE_SHUTDOWN != 'y' ]]; do
  echo "Would you like to have the server and EC2 instance stop after 10 minutes of nobody online? [y/N]"
  read IDLE_SHUTDOWN
  IDLE_SHUTDOWN=`echo $IDLE_SHUTDOWN | tr [:upper:] [:lower:]`
  if [[ ${#IDLE_SHUTDOWN} -eq 0 ]]; then
    IDLE_SHUTDOWN='n'
  fi
done

if [[ $IDLE_SHUTDOWN = 'y' ]]; then
  echo "Adding to /etc/crontab..."
  cat ~/scripts-tmp/crontab | sudo tee -a /etc/crontab > /dev/null
else
  cp ~/scripts-tmp/crontab ~/.idle-shutdown-crontab
  echo 'If you would like to enable idle shutdown in the future, run `cat ~/.idle-shutdown-crontab | sudo tee -a /etc/crontab` to add it to the system crontab.'
fi

# cleanup
cd ~
rm -r scripts-tmp
rm ec2mc.tar.gz
rm s3cmd-1.0.1.tar.gz
sudo rm -rf s3cmd-1.0.1
rm c10t-1.9-linux-x86.tar.gz
rm -r c10t-1.9-linux-x86

echo ''
echo 'Setup complete! Run `nano ~/bin/mc` to edit configuration options, and run `mc start` to start the server.'
echo 'If No-IP configuration failed, run `sudo /usr/local/bin/noip2 -C` and `sudo /etc/init.d/noip start`.'
if [[ $BACKUP_MODE = 's3' ]]; then
  echo " - Since you're using S3 for backups, be sure to create a bucket named '$BUCKET_NAME' (as set in ~/bin/mc)."
else
  echo ' - If you wish to back up with S3 at a later time, run `s3cmd --configure` and change DEFAULT_BACKUP_MODE and S3_BUCKET_NAME in the ~/bin/mc script.'
fi
echo ''