# Ambiente de desenvolvimento/testes. Não é imagem de produção.
FROM ruby:3.3-slim

ENV BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential git libyaml-dev nodejs \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Mesmo UID/GID do host para não criar arquivos de root no projeto.
ARG USER_ID=1000
ARG GROUP_ID=1000
RUN groupadd -g $GROUP_ID appgroup \
 && useradd -u $USER_ID -g appgroup -m -s /bin/bash appuser \
 && chown -R appuser:appgroup /app /usr/local/bundle \
 && echo 'source /app/.devcontainer/.bashrc' >> /home/appuser/.bashrc

USER appuser

CMD ["bash", "-lc", "(bundle check > /dev/null || bundle install); sleep infinity"]
