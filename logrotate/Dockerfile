FROM alpine:3.13

# Environment variables to run vault crontab hourly and create vault user
ENV CRON_SCHEDULE='0 * * * *' \ 
    USER=vault \
    UID=100 \
    GID=1000 

RUN apk update \
     && apk upgrade \
     && apk --update --no-cache add logrotate libintl procps dcron libcap busybox-suid tini
# User and Group Creation 
RUN addgroup -S -g $GID $USER
RUN adduser \
       --disabled-password \
       --gecos "" \
       --home /home/$USER \
       --ingroup $USER \
       --no-create-home \
       --uid $UID \
       $USER
RUN mkdir /home/$USER \
       && chown  $USER:$USER /home/$USER
# Change ownership of crond 
RUN chown  $USER:$USER /usr/sbin/crond \
      && setcap cap_setgid=ep /usr/sbin/crond
RUN echo "$CRON_SCHEDULE /usr/sbin/logrotate /etc/logrotate.conf -s /tmp/logrotate.status" > /home/$USER/$USER.cron
RUN chown -R  $USER:$USER \
       /home/$USER/$USER.cron \
       /etc/crontabs/ 
RUN chown $USER:$USER /usr/bin/crontab
RUN crontab -u $USER /home/$USER/$USER.cron 
# Remove root crontab
RUN crontab -r root \
    && rm -f /etc/crontabs/root
# Change ownership of users crontab 
RUN chown -R $USER:$USER /etc/crontabs/ /usr/bin/crontab 
RUN chmod -R 700 /etc/crontabs/ 


COPY --chown=$USER:$USER entrypoint.sh /usr/local/bin/entrypoint.sh

USER $USER
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/crond", "-f", "-L", "/dev/stdout"]
