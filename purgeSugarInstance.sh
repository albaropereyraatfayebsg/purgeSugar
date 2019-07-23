#! /bin/sh -

if [ "X-h" = "X$1" ];
then
  printf "This script purges a Sugar instance.\n";
  printf "%s sugaranidemo\n" "$(basename -az $0)";
  exit 0;
fi

# Initialize Global vars
httpdRootDir="/var/www/html/";
sqlConfig=".tmp.cnf"
if [ -z "$1" ];
then
  printf "Enter the name of the directory you woud like to purge: ";
  read dir;
else
  dir="$1";
fi

# Get sitePath
sitePath=$(sudo find ${httpdRootDir} -maxdepth 2 -type d -name ${dir} -print)
if [ -z "$sitePath" ];
then
  printf "The directory you entered %s does not exist.\n" "$dir";
  exit 1;
fi

# Get SugarPath
if [ -f "$sitePath/sugar_version.json" ];
then
  sugarPath="$sitePath"
elif [ -f "$sitePath/crm/sugar_version.json" ];
then
  sugarPath="$sitePath/crm"
else
  printf "Unable to locate Sugar instance";
  exit 1;
fi

# Get config_overide.php file path
config_override_file_path=$(sudo find "${sugarPath}" -maxdepth 1 -type f -name 'config_override.php');

if [ "$config_override_file_path" ]; then
  include_config_override="include '${config_override_file_path}';";
fi

# remove back-ups
############## Debugging code =====
./purgeBackups.sh "$dir";
# create a back-up and throw it in s3
./createS3Backup.sh $dir;
# Shutoff cron jobs
# This involves getting the etry removed and having the cron process read the updated file
tmpCrontabFile="tmp.cron";
escapedSitePath=$(printf "%s" "$sitePath" | sed 's/\//\\\//g');
sudo crontab -u www-data -l | sed -e "/^.*$escapedSitePath.*\$/d" > $tmpCrontabFile;
sudo crontab -u www-data $tmpCrontabFile;

# Remove elastic search
httpdDir=${sitePath#$httpdRootDir}
sugarutils --elasticsearch --delete-cluster $httpdDir; # Auto yes and run curl with -s

# Drop dabase

# dbName
sugar_config_string="\$sugar_config['dbconfig']['db_name']";
dbName=$(sudo php -r "require '${sugarPath}/config.php';${include_config_override}if(isset(${sugar_config_string})){print_r(${sugar_config_string});}");
# DB userName
sugar_config_string="\$sugar_config['dbconfig']['db_user_name']";
username=$(sudo php -r "require '${sugarPath}/config.php';${include_config_override}if(isset(${sugar_config_string})){print_r(${sugar_config_string});}");
printf "%s," "$username";
# DB password
sugar_config_string="\$sugar_config['dbconfig']['db_password']";
password=$(sudo php -r "require '${sugarPath}/config.php';${include_config_override}if(isset(${sugar_config_string})){print_r(${sugar_config_string});}");
printf "%s," "$password";
# Login to DB
sugar_config_string="\$sugar_config['dbconfig']['db_host_name']";
host=$(sudo php -r "require '${sugarPath}/config.php';${include_config_override}if(isset(${sugar_config_string})){print_r(${sugar_config_string});}");
# Create .cnf file and run drop command
if [ "$host" ] && [ "$dbName" ] && [ "$username" ] && [ "password" ];
then

  oldUmask=$(umask -S);
  umask 0377;
  tee <<EOF >$sqlConfig
[client]
user = $username
password = $password
host = $host
EOF
  umask $oldUmask;

  sqlQuery="DROP DATABASE $dbName;";
  # Note: -Bse 'B' Removes output formating 's' Removes header 'e' Executes commands seperated by ';'
  dbSize=$(mysql --defaults-extra-file=.tmp.cnf ${dbName} -Bse "${sqlQuery}" 2> /dev/null);

  if [ "${dbSize}" ];
  then
    # This may be misguiding since drop does not return values
    printf "The DB has been dropped succesfully.\n";
  else
    printf "There was an error droping the table: %s\n" "${dbName}";
  fi
else
  printf "Unable to authenticate to MySQL server.\n";
fi

# Purge files in directory
printf "You are about to remove all of the files in %s are you sure?\nPress any key to continue..." "$sitePath";
read anyKey;
rm -rf $sqlConfig;
sudo rm -rf $sitePath;
