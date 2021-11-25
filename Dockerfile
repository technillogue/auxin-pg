FROM ghcr.io/rust-lang/rust:nightly as builder
WORKDIR /src
RUN git clone https://github.com/forestcontact/auxin && cd auxin && git pull origin 0.1.4
WORKDIR /app
RUN rustup default nightly
# from https://stackoverflow.com/questions/58473606/cache-rust-dependencies-with-docker-build
RUN mkdir -p /app/auxin_cli/src /app/auxin/src
RUN mv /src/auxin/Cargo.toml .
RUN mv /src/auxin/auxin/Cargo.toml ./auxin
RUN mv /src/auxin/auxin_cli/Cargo.toml /app/auxin_cli/
RUN mv /src/auxin/auxin_protos /app/auxin_protos
RUN mv /app/auxin_protos/build.rs.always /app/auxin_protos/build.rs
WORKDIR /app/auxin_cli
# build dummy auxin_cli using latest Cargo.toml/Cargo.lock
RUN echo 'fn main() { println!("Dummy!"); }' > ./src/lib.rs
RUN echo 'fn lib() { println!("Dummy!"); }' > ../auxin/src/lib.rs
RUN find /app/
RUN cargo build --release
RUN rm -r /app/auxin/src /app/auxin_cli/src
RUN mv /src/auxin/auxin/src /app/auxin/src
RUN mv /src/auxin/auxin/data /app/auxin/data
RUN mv /src/auxin/auxin_cli/src /app/auxin_cli/src
RUN find /app/auxin_cli
RUN touch -a -m /app/auxin_cli/src/main.rs
RUN cargo +nightly build --release

#FROM ghcr.io/rust-lang/rust:nightly as builder
#WORKDIR /src
#RUN git clone https://github.com/technillogue/auxin-pg && cd auxin-pg/pgrx
# build pgxr??

FROM ubuntu:hirsute as libbuilder
WORKDIR /app
RUN ln --symbolic --force --no-dereference /usr/share/zoneinfo/EST && echo "EST" > /etc/timezone
RUN apt update
RUN DEBIAN_FRONTEND="noninteractive" apt install -yy python3.9 python3.9-venv pipenv
RUN python3.9 -m venv /app/venv
COPY Pipfile.lock Pipfile /app/
RUN VIRTUAL_ENV=/app/venv pipenv install 
#RUN VIRTUAL_ENV=/app/venv pipenv run pip uninstall dataclasses -y

FROM postgres:11-bullseye
ENV POSTGRES_HOST_AUTH_METHOD=trust 
RUN apt-get update && apt-get -yy install postgresql-11-cron curl python3.9  jq
RUN apt-get clean autoclean && apt-get autoremove --yes && rm -rf /var/lib/{apt,dpkg,cache,log}/
RUN chmod -R 777 /docker-entrypoint-initdb.d/
USER postgres
WORKDIR /var/lib/postgresql
RUN mkdir python
COPY --from=builder /app/target/release/auxin-cli ./python/auxin-cli
COPY --from=libbuilder /app/venv/lib/python3.9/site-packages ./python/
COPY ./datastore.py ./utils.py ./pghelp.py ./python/
COPY ./01-auxin.sql ./02-restart.sh ./03-load-cron.sql /docker-entrypoint-initdb.d/
COPY ./entrypoint.sh /var/lib/postgresql/
ENTRYPOINT ["/bin/bash", "/var/lib/postgresql/entrypoint.sh"]
#RUN sh -c 'postgres' & sleep 1 && psql -f /auxin.sql
