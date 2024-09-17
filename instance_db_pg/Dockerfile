FROM hashicorp/terraform:latest
RUN mkdir -p /app/.ssh
WORKDIR /app

RUN apk add --no-cache curl openssh-client bash
RUN eval "$(ssh-agent -s)"
RUN ssh-keygen -q -t rsa -N '' -f /app/.ssh/id_rsa

ADD ./terraform /app/terraform/

EXPOSE 80 5432 6432

ADD entrypoint.sh /root/entrypoint.sh
RUN chmod +x /root/entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
