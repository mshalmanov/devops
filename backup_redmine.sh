#!/bin/bash
BACKUPDIR=/var/backups/mysql #Путь к каталогу где будут храниться резервные копии
SITE=/opt/redmine/
TIME=`date +%d-%m-%Y` #Префикс по дате для структурирования резервных копий

#start arvive site.tar.gz
if [ -e $BACKUPDIR/site-$TIME.tar.gz ]
then
echo "Каталог $$BACKUPDIR/site-$TIME.tar.gz существует"
rm -rf $BACKUPDIR/site-$TIME.tar.gz
echo "Создать архив $BACKUPDIR/site-$TIME.tar.gz"
tar -czvf $BACKUPDIR/site-$TIME.tar.gz $SITE
else
echo "Создать архив $BACKUPDIR/site-$TIME.tar.gz"
tar -czvf $BACKUPDIR/site-$TIME.tar.gz $SITE
fi

#cron запускать каждый день в 23:00 
#23 00 * * * /opt/backup_redmine.sh