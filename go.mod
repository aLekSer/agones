module agones.dev/agones

go 1.12

require (
	cloud.google.com/go v0.34.0 // indirect
	contrib.go.opencensus.io/exporter/stackdriver v0.8.0
	fortio.org/fortio v1.3.1
	github.com/BurntSushi/toml v0.3.1 // indirect
	github.com/ahmetb/gen-crd-api-reference-docs v0.1.1
	github.com/aws/aws-sdk-go v1.16.20 // indirect
	github.com/dvyukov/go-fuzz v0.0.0-20191022152526-8cb203812681 // indirect
	github.com/elazarl/go-bindata-assetfs v1.0.0 // indirect
	github.com/evanphx/json-patch v4.5.0+incompatible // indirect
	github.com/fsnotify/fsnotify v1.4.7
	github.com/go-openapi/spec v0.19.0
	github.com/gogo/protobuf v1.2.1 // indirect
	github.com/golang/groupcache v0.0.0-20171101203131-84a468cf14b4 // indirect
	github.com/golang/protobuf v1.2.0
	github.com/google/btree v0.0.0-20180813153112-4030bb1f1f0c // indirect
	github.com/google/gofuzz v1.0.0 // indirect
	github.com/google/uuid v1.1.0 // indirect
	github.com/googleapis/gnostic v0.1.0 // indirect
	github.com/gregjones/httpcache v0.0.0-20181110185634-c63ab54fda8f // indirect
	github.com/grpc-ecosystem/grpc-gateway v1.5.1
	github.com/hashicorp/golang-lru v0.5.1 // indirect
	github.com/heptiolabs/healthcheck v0.0.0-20171201210846-da5fdee475fb
	github.com/imdario/mergo v0.3.5 // indirect
	github.com/joonix/log v0.0.0-20180502111528-d2d3f2f4a806
	github.com/json-iterator/go v1.1.5 // indirect
	github.com/mattbaird/jsonpatch v0.0.0-20171005235357-81af80346b1a
	github.com/munnerz/goautoneg v0.0.0-20120707110453-a547fc61f48d
	github.com/onsi/ginkgo v1.8.0 // indirect
	github.com/onsi/gomega v1.5.0 // indirect
	github.com/pborman/uuid v1.2.0 // indirect
	github.com/peterbourgon/diskv v2.0.1+incompatible // indirect
	github.com/pkg/errors v0.8.1
	github.com/prometheus/client_golang v0.9.2
	github.com/sirupsen/logrus v1.2.0
	github.com/spf13/pflag v1.0.3
	github.com/spf13/viper v1.3.1
	github.com/stephens2424/writerset v1.0.2 // indirect
	github.com/stretchr/testify v1.3.0
	go.opencensus.io v0.18.0
	golang.org/x/net v0.0.0-20190620200207-3b0461eec859
	golang.org/x/time v0.0.0-20180412165947-fbb02b2291d2
	golang.org/x/tools v0.0.0-20191126055441-b0650ceb63d9
	google.golang.org/api v0.0.0-20190117000611-43037ff31f69 // indirect
	google.golang.org/genproto v0.0.0-20190111180523-db91494dd46c
	google.golang.org/grpc v1.17.0
	gopkg.in/DATA-DOG/go-sqlmock.v1 v1.3.0 // indirect
	gopkg.in/fsnotify.v1 v1.4.7
	gopkg.in/inf.v0 v0.9.1 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.0.0-20170531160350-a96e63847dc3
	gopkg.in/yaml.v2 v2.2.2
	k8s.io/api v0.0.0-20191004102255-dacd7df5a50b // kubernetes-1.13.12
	k8s.io/apiextensions-apiserver v0.0.0-20191004105443-a7d558db75c6 // kubernetes-1.13.12
	k8s.io/apimachinery v0.0.0-20191004074956-01f8b7d1121a // kubernetes-1.13.12
	k8s.io/client-go v0.0.0-20191004102537-eb5b9a8cfde7 // kubernetes-1.13.12
	k8s.io/kube-openapi v0.0.0-20190709113604-33be087ad058 // indirect
	sigs.k8s.io/yaml v1.1.0 // indirect
)

replace k8s.io/apimachinery => ./vendor_fixes/k8s.io/apimachinery
