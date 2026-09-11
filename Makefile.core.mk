# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

gen: generate-k8s-client

clean: clean-k8s-client

applyconfiguration_gen = applyconfiguration-gen
kubetype_gen = kubetype-gen
deepcopy_gen = deepcopy-gen
client_gen = client-gen
lister_gen = lister-gen
informer_gen = informer-gen

kube_dubbo_source_packages = $(subst $(space),$(empty), \
    github.com/dubml/api/security/v1alpha3, \
    github.com/dubml/api/networking/v1alpha3, \
    github.com/dubml/api/telemetry/v1alpha3 \
    )

kube_base_output_package = github.com/dubml/client-go/pkg
kube_api_base_package = $(kube_base_output_package)/apis

kube_api_packages = $(subst $(space),$(empty), \
    $(kube_api_base_package)/security/v1alpha3, \
    $(kube_api_base_package)/networking/v1alpha3, \
    $(kube_api_base_package)/telemetry/v1alpha3 \
    )
kube_api_package_list = $(subst $(comma),$(space),$(kube_api_packages))

kube_api_applyconfiguration_packages = $(kube_api_packages),k8s.io/apimachinery/pkg/apis/meta/v1
kube_clientset_package = $(kube_base_output_package)/clientset
kube_clientset_name = versioned
kube_listers_package = $(kube_base_output_package)/listers
kube_informers_package = $(kube_base_output_package)/informers
kube_applyconfiguration_package = $(kube_base_output_package)/applyconfiguration
kube_go_header_text = header.go.txt

empty:=
space := $(empty) $(empty)
comma := ,

move_generated=\
	([ -d $(GOPATH)/src/$(kube_base_output_package)/ ] && mkdir -p pkg && cp -R $(GOPATH)/src/$(kube_base_output_package)/. pkg/ && rm -rf $(GOPATH)/src/$(kube_base_output_package)/) || true; \
	([ -d github.com/dubml/client-go/pkg/ ] && mkdir -p pkg && cp -R github.com/dubml/client-go/pkg/. pkg/ && rm -rf github.com) || true

rename_generated_files=\
	find $(subst github.com/dubml/client-go/, $(empty), $(subst $(comma), $(space), $(kube_api_packages) $(kube_clientset_package) $(kube_listers_package) $(kube_informers_package))) \
	-name '*.go' -and -not -name 'doc.go' -and -not -name '*.gen.go' -type f -exec sh -c 'mv "$$1" "$${1%.go}".gen.go' - '{}' \; || true

fixup_generated_files=\
	find . -name "*.deepcopy.gen.go" -type f -exec perl -0pi -e 's/^.*\*out = \*in.*\n//mg' {} +; \
	find pkg/clientset -path '*/fake/fake_*.gen.go' -type f -exec perl -0pi -e 's/return gentype\.ToPointerSlice\(list\.Items\)/return list.Items/g; s/list\.Items = gentype\.FromPointerSlice\(items\)/list.Items = items/g' {} +

.PHONY: generate-k8s-client
generate-k8s-client:
	# generate kube api type wrappers for dubbo types
	@GODEBUG=gotypesalias=0 $(kubetype_gen) --input-dirs $(kube_dubbo_source_packages) --output-package $(kube_api_base_package) -h $(kube_go_header_text)
	@$(move_generated)
	# generate deepcopy for kube api types
	@$(deepcopy_gen) --output-file zz_generated.deepcopy.gen.go --go-header-file $(kube_go_header_text) $(kube_api_package_list)
	# generate ssa for kube api types
	@$(applyconfiguration_gen) --output-dir pkg/applyconfiguration --output-pkg $(kube_applyconfiguration_package) --go-header-file $(kube_go_header_text) $(kube_api_package_list)
	# generate clientsets for kube api types
	@$(client_gen) --clientset-name $(kube_clientset_name) --input-base "" --input $(kube_api_packages) --output-dir pkg/clientset --output-pkg $(kube_clientset_package) --go-header-file $(kube_go_header_text) --apply-configuration-package $(kube_applyconfiguration_package)
	# generate listers for kube api types
	@$(lister_gen) --output-dir pkg/listers --output-pkg $(kube_listers_package) --go-header-file $(kube_go_header_text) $(kube_api_package_list)
	# generate informers for kube api types
	@$(informer_gen) --output-dir pkg/informers --output-pkg $(kube_informers_package) --versioned-clientset-package $(kube_clientset_package)/$(kube_clientset_name) --listers-package $(kube_listers_package) --go-header-file $(kube_go_header_text) $(kube_api_package_list)
	@$(move_generated)
	@$(rename_generated_files)
	@$(fixup_generated_files)

.PHONY: clean-k8s-client
clean-k8s-client:
    # remove generated code
	@rm -rf pkg/applyconfiguration pkg/clientset pkg/informers pkg/listers
	@find pkg/apis -name 'zz_generated.deepcopy.gen.go' -delete 2>/dev/null || true
