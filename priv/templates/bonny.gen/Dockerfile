FROM elixir:1.7.4-alpine

ENV MIX_ENV=prod \
    MIX_HOME=/opt/mix \
    HEX_HOME=/opt/hex

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

COPY . .

RUN mix deps.get --only-prod && \
    mix deps.compile && \
    mix compile

CMD ["mix", "run", "--no-halt"]
