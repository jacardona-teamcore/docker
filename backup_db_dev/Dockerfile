FROM hashicorp/terraform:latest
RUN mkdir -p /app/.ssh
WORKDIR /app

RUN apk add --no-cache curl openssh-client bash
RUN eval "$(ssh-agent -s)"
RUN ssh-keygen -q -t rsa -N '' -f /app/.ssh/id_rsa

ADD execute /home/execute
ADD modules /home/modules

ADD entrypoint.sh /home/entrypoint.sh
RUN chmod +x /home/entrypoint.sh

ENTRYPOINT ["/home/entrypoint.sh"]