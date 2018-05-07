#!/bin/bash

# gitlab-runner data directory
DATA_DIR="/etc/gitlab-runner"
CONFIG_FILE=${CONFIG_FILE:-$DATA_DIR/config.toml}
# custom certificate authority path
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-$DATA_DIR/certs/ca.crt}
LOCAL_CA_PATH="/usr/local/share/ca-certificates/ca.crt"

update_ca() {
  echo "Updating CA certificates..."
  cp "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}"
  update-ca-certificates --fresh >/dev/null
}

if [ -f "${CA_CERTIFICATES_PATH}" ]; then
  # update the ca if the custom ca is different than the current
  cmp --silent "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}" || update_ca
fi

### custom entrypoint stuff

# Determine if runner is already configured / registered
if [[ $(cat /etc/gitlab-runner/config.toml | grep -vi runners) ]]; then
  echo "Waiting for GitLab server, $GITLAB_SERVER, to start..."
  while ! nc -v -z "$GITLAB_SERVER" 80; do   
  	sleep 10
  done
  echo "GitLab server started!"

  sleep 30
  if [[ "$RUNNER_EXECUTOR" == 'docker' ]]; then
  	extra_args="--docker-image $DOCKER_IMAGE --docker-privileged"
  fi
  gitlab-runner register --non-interactive \
    --url "http://$GITLAB_SERVER" \
    --name "gitlab-runner-$RUNNER_EXECUTOR-$(hostname)" \
    --registration-token "$GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN" \
    --request-concurrency "$RUNNER_REQUEST_CONCURRENCY" \
    --limit "$RUNNER_LIMIT" \
    --run-untagged \
    --executor "$RUNNER_EXECUTOR" \
    $extra_args
fi

gitlab-runner verify

### end custom stuff

# launch gitlab-runner passing all arguments
exec gitlab-runner "$@"