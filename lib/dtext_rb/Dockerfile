FROM ruby:3.4.5@sha256:73e085e58f9496502b0463a787b497b961d946bc1db43c6782c0c3c95281e432
WORKDIR /dtext

RUN <<EOS
  apt-get update
  apt-get install ragel=6.10-4
EOS

COPY --link dtext_rb.gemspec lib/dtext/version.rb Gemfile Gemfile.lock .
COPY --link lib/dtext/version.rb lib/dtext/version.rb
RUN bundle install

COPY . .
RUN bin/rake compile

CMD bash
