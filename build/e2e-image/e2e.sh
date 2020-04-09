#!/usr/bin/env bash

# Copyright 2018 Google LLC All Rights Reserved.
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
set -e
echo "installing current release"
DOCKER_RUN= make install VERSION=1.5.0-a8ffcb8
echo "starting e2e test + ${VERSION}"
DOCKER_RUN= make stress-test-e2e ARGS="-parallel=64 -v " STRESS_TEST_LEVEL=1
echo "completed e2e test"