# create a deploy group
./bin/zz deploy_group_create --group photos_staging --app_name photos --rails_env photos_staging --vhost staging.photos.zangzing.com --email_host staging.zangzing.com --app_git_url git@github.com:zangzing/server.git --amazon_security_key amazon_staging --amazon_security_group security_staging --amazon_image baseline_staging --amazon_elb photos-staging-balancer --database_host zz-staging-rds.ckikxby0s3p8.us-east-1.rds.amazonaws.com --database_username zzadmin --database_password pwy4ksp3psd0 --database_schema photos_staging

# list deploy groups
./bin/zz deploy_group_list

# delete deploy group
./bin/zz deploy_group_delete --group photos_staging

# add servers
./bin/zz add -z us-east-1c -s c1.medium -g photos_staging -r app_master
./bin/zz add -z us-east-1c -g photos_staging -r app
./bin/zz add -z us-east-1c -g photos_staging -r util
./bin/zz add -z us-east-1c -g photos_staging -r util
./bin/zz add -z us-east-1c -g photos_staging -r db

# delete server
./bin/zz delete -g photos_staging -w -i i-b74554d9

# list servers
./bin/zz list --group photos_staging

# ssh
./bin/zz ssh --group photos_staging

# multi ssh
./bin/zz multi_ssh -g photos_staging "ls -al"

# upload chef
# tag first like
# git tag TD5
# git push origin TD5
./bin/zz chef_upload --group photos_staging --tag TD8

# deploy chef
./bin/zz chef_bake --group photos_staging

# deploy instance
./bin/zz deploy --group photos_staging --tag master

# maint page up
./bin/zz maint --group photos_staging --maint

# maint page down
./bin/zz maint --group photos_staging --no-maint

# create amazon config
./bin/zz config_amazon --akey AmazonAccessKey --skey AmazonSecretKey


# sample to prep new group (use your name instead of greg below)
zz deploy_group_create --group photos_greg --app_name photos --rails_env photos_staging --vhost greg.photos.zangzing.com --email_host greg.mailhost.zangzing.com --app_git_url git@github.com:zangzing/server.git --amazon_security_key amazon_staging --amazon_security_group security_staging --amazon_image baseline_staging --amazon_elb greg-photos-balancer --database_host zz-staging-rds.ckikxby0s3p8.us-east-1.rds.amazonaws.com --database_username zzadmin --database_password pwy4ksp3psd0 --database_schema photos_greg