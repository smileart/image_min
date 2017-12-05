FROM ruby:2.4.1

# RUN apk --update --upgrade add build-base
RUN apt-get update && apt-get install -y curl openssh-server

RUN mkdir /app
WORKDIR /app

ADD Gemfile Gemfile.lock /app/
RUN bundle install

ADD . /app
ADD ./.profile.d /app/.profile.d

CMD cd /app/ && rackup --env $RACK_ENV --server puma --port $PORT
