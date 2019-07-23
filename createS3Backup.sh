#! /bin/sh -

if [ "X-h" = "X$1" ];
then
  printf "\
This script creates a Sugar backup and pushes it to s3.\n\
%s sugaranidemo\n\
" \
"$(basename -az $0)";
  exit 0;
fi

# Variables
bucketName="$(sh ${0%/*}/private/getBucketName.sh)";

httpdRootDir="/var/www/html/";
escapedHttpdRootDir=$(printf "%s" "$httpdRootDir" | sed 's/\//\\\//g');

if [ -z "$1" ];
then
  printf "Enter the name of the directory you woud like to backup to S3.\n";
  read dir;
else
  dir="$1";
fi

sitePath=$(sudo find ${httpdRootDir} -maxdepth 2 -type d -name ${dir} -print)
if [ -z "$sitePath" ];
then
  prinf "The directory you entered %s does not exist.\n" "$dir";
  exit 1;
fi

httpdDir=${sitePath#$httpdRootDir}
archiveHttpdDir=$(printf "%s" "$httpdDir"| sed 's/\//_/g');

# get Sugar directory
if [ -f "$sitePath/sugar_version.json" ];
then
  sugarPath="$sitePath"
elif [ -f "$sitePath/crm/sugar_version.json" ];
  then
   sugarPath="$sitePath/crm"
else
  printf "This is not a Sugar directory"
fi

# Get config_overide.php file path
config_override_file_path=$(sudo find "${sugarPath}" -maxdepth 1 -type f -name 'config_override.php');

if [ "$config_override_file_path" ]; then
  include_config_override="include '${config_override_file_path}';";
fi
# Sugar edition
sugarFlavor=$(jq '.sugar_flavor' "${sugarPath}/sugar_version.json" | sed 's/"//g');
# DB Name
sugar_config_string="\$sugar_config['dbconfig']['db_name']";
dbName=$(sudo php -r "require '${sugarPath}/config.php';${include_config_override}if(isset(${sugar_config_string})){print_r(${sugar_config_string});}");

# Crete new backup using sugarutils
sugarutils --create-backup --quick --dump-database $httpdDir;
mkdir -p $httpdDir;
# Move backup into $httpdDir
sudo find "$sitePath" -maxdepth 3 -type f -name "${archiveHttpdDir}_*${sugarFlavor}_????-???-??T??????\.tar\.gz" -exec mv {} $httpdDir \;
sudo find "$sitePath" -maxdepth 3 -type f -name "${dbName}_*${sugarFlavor}_data_dump\.????-???-??T??????\.sql" -exec mv {} $httpdDir \;
# Move $httpdDire to s3
aws s3 cp $httpdDir s3://"$bucketName" --recursive;
# on sucess
rm -rm $httpdDir;
