#! /usr/bin/env bash
[ -z "$SSH_CLIENT" ] && curl --fail --retry 3 -sSL "$HEROKU_EXEC_URL" > /tmp/exec.sh && bash /tmp/exec.sh
