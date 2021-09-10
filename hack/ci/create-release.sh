#!/usr/bin/env bash
# Copyright 2021 VMware
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get -y update && apt-get install -y wget curl perl ca-certificates gnupg lsb-release && update-ca-certificates && rm -rf /var/lib/apt/lists/*

bash -c "set -eo pipefail; curl -L https://carvel.dev/install.sh | bash"

ytt version && kapp version && kbld version && kwt version && imgpkg version && vendir version

curl -L https://github.com/google/ko/releases/download/v0.8.3/ko_0.8.3_Linux_arm64.tar.gz | tar xzf - ko
mv ko /usr/local/bin/ko
chmod +x /usr/local/bin/ko

cp hack/ci/docker-login.sh /usr/local/bin/docker-login.sh
chmod +x /usr/local/bin/docker-login.sh

mkdir -p ~/.docker
docker-login.sh ~/.docker/config.json
mkdir -p /usr/local/go/src/github.com/vmware-tanzu
ln -s $(pwd) /usr/local/go/src/github.com/vmware-tanzu/cartographer

ytt --ignore-unknown-comments -f ./config | ko resolve -f- > release.yaml

echo "# Change Set" > CHANGELOG.md
git tag --sort=-v:refname -l "v*" | grep -C1 "${GITHUB_REF##*/}" | tail -2 | xargs printf '%s..%s' | xargs -I{} git -c log.showSignature=false log --pretty=oneline --abbrev-commit --no-decorate --no-color {} >> CHANGELOG.md

echo "## Checksums" >> CHANGELOG.md
shasum=$(sha256sum release.yaml)
echo "$shasum" >> CHANGELOG.md
