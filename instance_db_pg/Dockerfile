FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh
ADD entrypoint.sh /home/entrypoint.sh
ADD ./terraform /app/terraform/

RUN mkdir -p /app/.ssh
WORKDIR /app

EXPOSE 80 5432 6432

RUN bash /root/configuracion.sh
RUN eval "$(ssh-agent -s)"
RUN ssh-keygen -q -t rsa -N '' -f /app/.ssh/id_rsa
RUN chmod +x /home/entrypoint.sh

ENTRYPOINT ["/home/entrypoint.sh"]
