#!/bin/bash
TIME=`date +%d-%m-%Y`
MYSQLUSER=root
MYSQLPASS=root
BACKUPDIR=/var/backups/mysql

mkdir -p $BACKUPDIR
#chmod -R 747 $BACKUPDIR
for base in my mybuh_currency
do
mysqldump -u$MYSQLUSER -p$MYSQLPASS -B $base > $BACKUPDIR/$base-$TIME.sql
done 

#create current tar.gz 
for i in "${BACKUPDIR}"
do
    filename=$BACKUPDIR/backup-$TIME.tar.gz
    find $i \(-type f -name "*-$TIME.sql" \) -print0 | tar -czvf $filename $BACKUPDIR/*-$TIME.sql
done
rm -rf $BACKUPDIR/*-$TIME.sql
#delete mount backup files
find $BACKUPDIR/* -mtime +30 -print -delete
