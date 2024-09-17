FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh

RUN mkdir -p /app/.ssh
WORKDIR /app

ADD ./terraform /app/terraform/

EXPOSE 80 5432 6432

ADD entrypoint.sh /home/entrypoint.sh
RUN bash /root/configuracion.sh
RUN eval "$(ssh-agent -s)"
RUN ssh-keygen -q -t rsa -N '' -f /app/.ssh/id_rsa
RUN chmod +x /home/entrypoint.sh

ENTRYPOINT ["/home/entrypoint.sh"]
