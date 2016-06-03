FROM ubuntu
MAINTAINER Nicholas Long nicholas.long@nrel.gov

# Install required libaries
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		bison \
  	    	build-essential \
		bzip2 \
		ca-certificates \
		curl \
		default-jdk \
		imagemagick \
		gdebi-core \
		git \
		libbz2-dev \
		libcurl4-openssl-dev \
		libgdbm3 \
		libgdbm-dev \
		libglib2.0-dev \
		libncurses-dev \
		libreadline-dev \
		libxml2-dev \
		libxslt-dev \
        	libffi-dev \
        	libssl-dev \
        	libyaml-dev \
		nodejs \
        	procps \
		ruby \
		tar \
		unzip \
		wget \
		zip \
		zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build and Install Ruby
#   -- skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.2
ENV RUBY_VERSION 2.2.4
ENV RUBY_DOWNLOAD_SHA256 b6eff568b48e0fda76e5a36333175df049b204e91217aa32a65153cc0cdcb761
ENV RUBYGEMS_VERSION 2.5.2

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN curl -fSL -o ruby.tar.gz "http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
        && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
        && mkdir -p /usr/src/ruby \
        && tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
        && rm ruby.tar.gz \
        && cd /usr/src/ruby \
        && { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c
RUN cd /usr/src/ruby \
  && autoconf \
        && ./configure --disable-install-doc --enable-shared
RUN cd /usr/src/ruby \
  && make -j"$(nproc)" \
        && make install \
        && apt-get purge -y --auto-remove $buildDeps \
        && echo :ssl_verify_mode: 0 >> /root/.gemrc \
        && gem update --system $RUBYGEMS_VERSION \
        && rm -r /usr/src/ruby

ENV BUNDLER_VERSION 1.11.2

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

# Install passenger (this also installs nginx)
RUN gem install passenger -v 5.0.25
RUN passenger-install-nginx-module

# First upload the Gemfile* so that it can cache the Gems -- do this first because it is slow
WORKDIR /srv
ADD Gemfile /srv/Gemfile
ADD Gemfile.lock /srv/Gemfile.lock
RUN bundle install

# Add the app assets and precompile assets. Do it this way so that when the app changes the assets don't
# have to be recompiled everytime
ADD Rakefile /srv/Rakefile
ADD /config/ /srv/config/
ADD /app/assets/ /srv/app/assets/

# Configure the nginx server
RUN mkdir /var/log/nginx
ADD docker/nginx.conf /opt/nginx/conf/nginx.conf

# Startup Script
ADD docker/start-server.sh /usr/bin/start-server
RUN chmod +x /usr/bin/start-server

# Build the assets
# First add the users model to prevent the error with not finding the User
ADD /app/models/user.rb /srv/app/models/user.rb
# Now call precompile
ENV RAILS_ENV docker

#RUN bundle exec rake assets:precompile

# Bundle app source
ADD / /srv

# Remove the logs because they need to be recreated
RUN rm -rf /srv/log
RUN mkdir /srv/log
RUN chmod 777 /srv/log

# Call the start-server script as the default command
# When debugging you can use CMD so that you can override the command otherwise use ENTRYPOINT
CMD ["/usr/bin/start-server"]

# Expose ports.
EXPOSE 80
