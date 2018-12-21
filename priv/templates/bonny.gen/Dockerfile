FROM bitwalker/alpine-elixir:1.7.4

ENV MIX_ENV=prod
USER default

COPY . /app
WORKDIR /app
RUN mix deps.get
CMD mix run --no-halt
