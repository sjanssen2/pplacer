## pplacer-build
## Build pplacer from source

FROM ubuntu:16.04
RUN apt-get -y update
RUN apt-get -y install \
camlp4=4.02.1+3-2 \
gawk=1:4.1.3+dfsg-0.1 \
libsqlite3-dev \
zlib1g-dev \
m4=1.4.17-5 \
wget \
ocaml=4.02.3-5ubuntu2 \
patch=2.7.5-1ubuntu0.16.04.2 \
build-essential=12.1ubuntu2 \
pkg-config=0.29.1-0ubuntu1 \
unzip=6.0-20ubuntu1 \
sqlite3 \
python=2.7.12-1~16.04 \
zip=3.0-11 \
git

# install gls 1.16
RUN mkdir /src
WORKDIR /src
RUN wget ftp://ftp.gnu.org/gnu/gsl/gsl-1.16.tar.gz
RUN tar xzvf gsl-1.16.tar.gz 
WORKDIR /src/gsl-1.16
RUN ./configure && make && make install

RUN wget https://raw.githubusercontent.com/ocaml/opam/1.3.1/shell/opam_installer.sh -O - | sh -s /usr/local/bin
RUN ln -s /usr/local/bin/opam /usr/bin/opam && /usr/local/bin/opam init -y
RUN opam repo add pplacer-deps http://matsen.github.com/pplacer-opam-repository &&  opam update pplacer-deps && eval `opam config env`
RUN opam install -y depext.1.0.5 && opam depext -y \
csv.1.6 \
ounit.2.0.8 \
xmlm.1.2.0 \
mcl.12-068oasis4 \
batteries.2.8.0 \
ocaml-gsl.0.6.3 \
sqlite3.4.1.3 \
camlzip.1.05 \
&& opam install -y \
csv.1.6 \
ounit.2.0.8 \
xmlm.1.2.0 \
mcl.12-068oasis4 \
batteries.2.8.0 \
ocaml-gsl.0.6.3 \
sqlite3.4.1.3 \
camlzip.1.05 

RUN mkdir /pplacer && mkdir /pplacer/src && mkdir /data
WORKDIR /pplacer/src
COPY ./ /pplacer/src/

RUN eval $(opam config env) && make
RUN cp /pplacer/src/bin/* /usr/local/bin
WORKDIR /pplacer/src/bin/ 
RUN zip /pplacer.zip *
WORKDIR /pplacer/src/
RUN zip /pplacer.zip ./scripts/*
WORKDIR /pplacer/src/scripts
RUN python setup.py install

WORKDIR /data
RUN rm -r /pplacer/src/
