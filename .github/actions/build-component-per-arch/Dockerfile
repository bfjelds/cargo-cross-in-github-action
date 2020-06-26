FROM amd64/ubuntu:16.04

RUN apt update && apt install -y curl gcc make

RUN curl -fsSL https://get.docker.com -o get-docker.sh
RUN sh get-docker.sh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]