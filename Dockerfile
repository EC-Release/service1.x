#
#  Copyright (c) 2019 General Electric Company. All rights reserved.
#
#  The copyright to the computer software herein is the property of
#  General Electric Company. The software may be used and/or copied only
#  with the written permission of General Electric Company or in accordance
#  with the terms and conditions stipulated in the agreement/contract
#  under which the software has been supplied.
#
#  author: apolo.yasuda@ge.com
#

FROM node:16-alpine
#FROM node:7

USER root
WORKDIR /root

COPY ./package.json ./

RUN apk update && apk add wget && apk add curl && apk add git && apk add tree && \
npm install

# deprecated cf support
#RUN curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&version=6.49.0&source=github-rel" | tar -zx && \
#mv cf /usr/local/bin && \
#cf --version

RUN wget -q --show-progress -O v1.linux64.sh https://raw.githubusercontent.com/EC-Release/sdk/disty/scripts/service1.x/v1.1.linux64.sh

RUN ls -al && chmod 755 v1.1.linux64.sh

ENTRYPOINT ["./v1.1.linux64.sh"]
