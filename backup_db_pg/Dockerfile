FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh
ADD ./backup_db.sh /home/backup_db.sh
ADD ./postgresql.conf /home/postgresql.conf

EXPOSE 80 5432 6432

RUN bash /root/configuracion.sh
RUN chmod +x /home/backup_db.sh

ENTRYPOINT ["/home/backup_db.sh"]
