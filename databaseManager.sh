#!/bin/sh

# Modify crontab
modifyCrontab()
{
    mkdir -p /home/hosting-user/anacrontab.bak/
    datetime=$(date +'%Y%m%d_%H%M')
    cp /srv/data/etc/cron/anacrontab /home/hosting-user/anacrontab.bak/anacrontab.${datetime}
	sed -i '/mysqldump/d' /srv/data/etc/cron/anacrontab
    sed -i '/delete/d' /srv/data/etc/cron/anacrontab
}

# Delete old database dump: > 7 days
deleteOldDatabase()
{
    currentdate="$(date +'%Y-%m-%d' -d "7 days ago")"
    find . -name "*${currentdate}.sql.gz" -type f -print -delete
    #task="find /home/hosting-user/database.bak/ -name "*$(date +'%Y-%m-%d' -d "7 days ago").sql.gz" -type f -print -delete ctime +7"
    #echo ${task} >> /srv/data/etc/cron/anacrontab 
}

# Export database
exportDatabase()
{
    echo "[START] ExportSQL" $(date +'%Y-%m-%d %H:%M')  >> database.log
    datetime=$(date +'%Y-%m-%d')

    if [ $1 = "all" ]
    then
        mysqldump -u ${userMysql} -p${passwordMysql} --all-databases --events | /bin/gzip > /home/hosting-user/database.bak/$1_${datetime}.sql.gz
        task="1@daily 0 cronExport$1 mysqldump -u $userMysql -p$passwordMysql --all-databases --events | /bin/gzip > /home/hosting-user/database.bak/$1_$datetime.sql.gz"
        echo ${task} >> /srv/data/etc/cron/anacrontab
    else
        mysqldump -u ${userMysql} -p${passwordMysql} --databases $1 | /bin/gzip > /home/hosting-user/database.bak/$1_${datetime}.sql.gz
        task="1@daily 0 cronExport$1 mysqldump -u $userMysql -p$passwordMysql --databases $1 | /bin/gzip > /home/hosting-user/database.bak/$1_$datetime.sql.gz"
        echo ${task} >> /srv/data/etc/cron/anacrontab
    fi
    echo "Database dump:" $1 >> database.log
    echo "[STOP] ExportSQL" $(date +'%Y-%m-%d %H:%M') >> database.log
}

listDatabase()
{
    # Database list
    query="
    SET @counter = 0; 
    SELECT (@counter := @counter +1) as counter, SCHEMA_NAME AS database_name 
    FROM SCHEMATA AS s 
    WHERE s.schema_name NOT IN ('information_schema', 'mysql', 'performance_schema') 
    ORDER BY schema_name;
    ;"

    mysql -u ${userMysql} -p${passwordMysql} -e "${query}" information_schema
}


main()
{
    deleteOldDatabase

    echo "Mysql username: "
    read userMysql
    echo "Mysql password: "
    read passwordMysql

    mkdir -p /home/hosting-user/database.bak/ 2>/dev/null

    listDatabase

    echo "Select databases for export (separated by space) or type 'all' for exporting all databases :"
    read databasenames

    echo "Please wait..."

    modifyCrontab

    if [ ${databasenames} = "all" ]
    then
        echo "Export: " ${databasenames}
        exportDatabase ${databasenames}
    else
        for databasename in ${databasenames}
        do
            echo "Export: " ${databasename}
            exportDatabase ${databasename}
        done
    fi
}

main

