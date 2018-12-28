FROM elixir:1.7.4-alpine

RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

COPY . .

RUN mix deps.get && \
    mix deps.compile

RUN mix compile

CMD ["mix", "test", "--cover"]
