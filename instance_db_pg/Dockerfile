FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh
ADD ./configuration_db.sh /home/configuration_db.sh
ADD ./restore_db.sh /home/restore_db.sh
ADD ./start_db.sh /home/start_db.sh
ADD ./configurations /home/configurations


EXPOSE 80 5432 6432

RUN bash /root/configuracion.sh

ENTRYPOINT ["/home/start_db.sh"]
