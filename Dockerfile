FROM node:10

RUN apt-get update && \
    apt-get install -y libpq-dev && \
    apt-get install -y python-dev && \
    apt-get install -y python-pip && \
    apt-get install -y jq

RUN pip install awscli

# Grab latest version of npm - don't rely on bundled version
RUN npm i npm@latest -g

RUN mkdir -p /opt/app/school-alerter

WORKDIR /opt/app/school-alerter

# First copy package.json so that we can cache dependencies separate from source code.
# By doing so, we won't have to rebuild layers with dependencies when source code changes occur.
COPY package.json package-lock.json* ./

# Build dependencies
RUN npm install && npm cache clean --force

# Done building dependency layers...

# Now add the entire source code tree
COPY . ./

CMD ./run.sh
