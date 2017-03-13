FROM centos:centos6

MAINTAINER Hiroaki Sano <hiroaki.sano.9stories@gmail.com>

# Basic packages
RUN rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm \
  && yum -y install passwd sudo git wget openssl openssh openssh-server openssh-clients

# Create user
RUN useradd hiroakis \
 && echo "hiroakis" | passwd hiroakis --stdin \
 && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
 && sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config \
 && echo "hiroakis ALL=(ALL) ALL" >> /etc/sudoers.d/hiroakis


# Ruby Installation

RUN sudo yum install -y git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel

RUN  git clone git://github.com/rbenv/rbenv.git /usr/local/rbenv \
&&  git clone git://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build \
&&  git clone git://github.com/jf/rbenv-gemset.git /usr/local/rbenv/plugins/rbenv-gemset \
&&  /usr/local/rbenv/plugins/ruby-build/install.sh
ENV PATH /usr/local/rbenv/bin:$PATH
ENV RBENV_ROOT /usr/local/rbenv

RUN echo 'export RBENV_ROOT=/usr/local/rbenv' >> /etc/profile.d/rbenv.sh \
&&  echo 'export PATH=/usr/local/rbenv/bin:$PATH' >> /etc/profile.d/rbenv.sh \
&&  echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh

RUN echo 'export RBENV_ROOT=/usr/local/rbenv' >> /root/.bashrc \
&&  echo 'export PATH=/usr/local/rbenv/bin:$PATH' >> /root/.bashrc \
&&  echo 'eval "$(rbenv init -)"' >> /root/.bashrc

ENV CONFIGURE_OPTS --disable-install-doc
ENV PATH /usr/local/rbenv/bin:/usr/local/rbenv/shims:$PATH

RUN eval "$(rbenv init -)"; rbenv install 2.4.0 \
&&  eval "$(rbenv init -)"; rbenv global 2.4.0 \
&&  eval "$(rbenv init -)"; gem update --system \
&&  eval "$(rbenv init -)"; gem install bundler


# Redis
RUN yum install -y redis


# RabbitMQ
RUN yum install -y erlang \
  && rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc \
  && rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.1.4/rabbitmq-server-3.1.4-1.noarch.rpm \
  && git clone git://github.com/joemiller/joemiller.me-intro-to-sensu.git \
  && cd joemiller.me-intro-to-sensu/; ./ssl_certs.sh clean && ./ssl_certs.sh generate \
  && mkdir /etc/rabbitmq/ssl \
  && cp /joemiller.me-intro-to-sensu/server_cert.pem /etc/rabbitmq/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/server_key.pem /etc/rabbitmq/ssl/key.pem \
  && cp /joemiller.me-intro-to-sensu/testca/cacert.pem /etc/rabbitmq/ssl/
ADD ./files/rabbitmq.config /etc/rabbitmq/
RUN rabbitmq-plugins enable rabbitmq_management

# Sensu server
ADD ./files/sensu.repo /etc/yum.repos.d/
RUN yum install -y sensu
ADD ./files/config.json /etc/sensu/
RUN mkdir -p /etc/sensu/ssl \
  && cp /joemiller.me-intro-to-sensu/client_cert.pem /etc/sensu/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/client_key.pem /etc/sensu/ssl/key.pem
# RUN chmod +x /etc/sensu/plugins/check-cpu.rb

# Plugins
RUN gem install sensu-plugins-disk-checks 

# uchiwa
RUN yum install -y uchiwa
ADD ./files/uchiwa.json /etc/sensu/

# supervisord
RUN wget http://peak.telecommunity.com/dist/ez_setup.py;python ez_setup.py \
  && easy_install supervisor
ADD files/supervisord.conf /etc/supervisord.conf

RUN /etc/init.d/sshd start && /etc/init.d/sshd stop

EXPOSE 22 3000 4567 5671 15672

CMD ["/usr/bin/supervisord"]

