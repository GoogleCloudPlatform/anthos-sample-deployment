# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: balancereader
  namespace: boa
spec:
  hosts:
  - balancereader.boa.global
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8080
    protocol: http
  resolution: DNS
  addresses:
  - 240.0.0.2
  endpoints:
  - address: GWIP_ONPREM
    ports:
      http1: 15443 # Do not change this port value
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: ledgerwriter
  namespace: boa
spec:
  hosts:
  - ledgerwriter.boa.global
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8080
    protocol: http
  resolution: DNS
  addresses:
  - 240.0.0.3
  endpoints:
  - address: GWIP_ONPREM
    ports:
      http1: 15443 # Do not change this port value
---
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: transactionhistory
  namespace: boa
spec:
  hosts:
  - transactionhistory.boa.global
  location: MESH_INTERNAL
  ports:
  - name: http1
    number: 8080
    protocol: http
  resolution: DNS
  addresses:
  - 240.0.0.4
  endpoints:
  - address: GWIP_ONPREM
    ports:
      http1: 15443 # Do not change this port value