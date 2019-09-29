#########################
###### Build Image ######
#########################

FROM bitwalker/alpine-elixir:1.9.1 as builder

ENV MIX_ENV=prod \
  MIX_HOME=/opt/mix \
  HEX_HOME=/opt/hex

RUN mix local.hex --force && \
  mix local.rebar --force

WORKDIR /app

COPY . .

RUN mix deps.get --only-prod && mix release

#########################
##### Release Image #####
#########################

FROM alpine:3.10

RUN apk add --update openssl ncurses

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/<%= app_name %> ./
RUN chown -R nobody: /app

ENTRYPOINT ["/app/bin/<%= app_name %>"]
CMD ["start"]
