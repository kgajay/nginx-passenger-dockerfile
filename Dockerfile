FROM ubuntu:14.04
MAINTAINER Ajay Gupta <ajay.gupta.9211@gmail.com>

#RUN mv /bin/sh /bin/sh~ && ln -s /bin/bash /bin/sh
RUN echo "$SHELL"

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf build-essential imagemagick libbz2-dev libcurl4-openssl-dev libevent-dev \
    libffi-dev libglib2.0-dev libjpeg-dev libmagickcore-dev libmagickwand-dev \
    libmysqlclient-dev libncurses-dev libpq-dev libreadline-dev libsqlite3-dev \
    libssl-dev libxml2-dev libxslt-dev libyaml-dev zlib1g-dev \
    ca-certificates curl nodejs apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# source https://github.com/docker-library/ruby/blob/b0dac732e8b7a64a32e09f1cc8fa93cea8edc785/2.1/Dockerfile
RUN set -x

RUN echo "*******************"
RUN echo "* Installing Ruby *"
RUN echo "*******************"

ENV RUBY_MAJOR 2.1
ENV RUBY_VERSION 2.1.10
ENV RUBY_DOWNLOAD_SHA256 fb2e454d7a5e5a39eb54db0ec666f53eeb6edc593d1d2b970ae4d150b831dd20
ENV RUBYGEMS_VERSION 2.6.6

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN set -ex \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends bison libgdbm-dev ruby \
	&& rm -rf /var/lib/apt/lists/*
RUN curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
    && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/ruby \
	&& tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.gz
WORKDIR /usr/src/ruby
RUN { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
	&& autoconf
WORKDIR /usr/src/ruby
RUN ./configure --disable-install-doc
RUN make -j"$(nproc)"
RUN make install
RUN apt-get purge -y --auto-remove bison libgdbm-dev ruby
WORKDIR /usr/src
RUN gem update --system "$RUBYGEMS_VERSION" \
	&& rm -rf /usr/src/ruby

RUN ruby -v

ENV BUNDLER_VERSION 1.12.5

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
#ENV GEM_HOME /usr/local/bundle
#ENV BUNDLE_PATH="$GEM_HOME" \
#	BUNDLE_BIN="$GEM_HOME/bin" \
#	BUNDLE_SILENCE_ROOT_WARNING=1 \
#	BUNDLE_APP_CONFIG="$GEM_HOME"
#ENV PATH $BUNDLE_BIN:$PATH
#RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
#	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

RUN echo "*******************"
RUN echo "* Ruby installed! *"
RUN echo "*******************"


# source https://www.digitalocean.com/community/tutorials/how-to-deploy-a-rails-app-with-passenger-and-nginx-on-ubuntu-14-04
RUN echo "*******************"
RUN echo "* Installing passenger *"
RUN echo "*******************"

ENV PASSENGER_VERSION 5.0.30
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 561F9B9CAC40B2F7
RUN echo 'deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main' >> /etc/apt/sources.list.d/passenger.list
RUN chown root: /etc/apt/sources.list.d/passenger.list
RUN chmod 600 /etc/apt/sources.list.d/passenger.list
RUN apt-get update && apt-get install -y --no-install-recommends nginx-extras passenger && rm -rf /var/lib/apt/lists/*
RUN rm -rf /usr/bin/ruby && ln -s /usr/local/bin/ruby /usr/bin/ruby

RUN echo "*******************"
RUN echo "* Passenger installed! *"
RUN echo "*******************"

RUN set +x

WORKDIR /usr/src/scripts
COPY Gemfile* /usr/src/scripts/
RUN bundle install
RUN rm -f /usr/src/scripts/Gemfile*

#WORKDIR /usr/src/apollo
#COPY . /usr/src/apollo
#RUN rm -rf /usr/src/apollo/log && mkdir /usr/src/apollo/log
#RUN touch /usr/src/apollo/log/newrelic_agent.log
#RUN chmod 777 /usr/src/apollo/log/newrelic_agent.log
# RUN bundle exec rake assets:precompile RAILS_ENV=production
# RUN bundle install
#RUN chmod -R 777 /usr/src/apollo

RUN mkdir -p /var/log/nginx/
COPY webapp.conf /etc/nginx/nginx.conf
COPY nginx-default.conf /etc/nginx/sites-available/default
COPY nginx-server.conf /etc/nginx/sites-available/apollo

CMD ["/bin/bash", "run.sh"]
