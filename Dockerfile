FROM ubuntu:16.04
MAINTAINER loggerhead "i@loggerhead.me"

ENV HOME /home/root
WORKDIR /home/root

RUN apt-get -y -qq update ;\
    apt-get -y -qq install build-essential libxslt-dev zlib1g-dev aria2
ADD build.sh build.sh
RUN ./build.sh

CMD ["bash"]
