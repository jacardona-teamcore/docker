FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh
ADD ./configuration_db.sh /root/configuration_db.sh
ADD ./restore_db.sh /root/restore_db.sh
ADD ./start_db.sh /root/start_db.sh
ADD ./configurations /root/configurations


EXPOSE 80 5432 6432

RUN bash /root/configuracion.sh

ENTRYPOINT ["/root/start_db.sh"]
