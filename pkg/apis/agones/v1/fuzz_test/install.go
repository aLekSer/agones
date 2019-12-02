
package install

import (
	"fmt"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	agonesv1 "agones.dev/agones/pkg/apis/agones/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

// Install registers the API group and adds types to a scheme
func Install(scheme *runtime.Scheme) {
	agonesv1.SchemeGroupVersion = schema.GroupVersion{Group: agonesv1.SchemeGroupVersion.Group, Version: runtime.APIVersionInternal}
	utilruntime.Must(agonesv1.AddToScheme(scheme))

	//utilruntime.Must(scheme.SetVersionPriority(agonesv1.SchemeGroupVersion))
	for externalGVK, externalGoType := range scheme.AllKnownTypes() {
		fmt.Println(externalGVK, externalGoType)
	}
}