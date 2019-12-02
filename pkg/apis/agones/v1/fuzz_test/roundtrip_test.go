package install
import (
	//"fmt"
	"testing"

	//"k8s.io/apimachinery/pkg/api/apitesting/fuzzer"
	"k8s.io/apimachinery/pkg/api/apitesting/roundtrip"
	//metafuzzer "k8s.io/apimachinery/pkg/apis/meta/fuzzer"

	//"k8s.io/apimachinery/pkg/runtime"
	agonesfuzzer "agones.dev/agones/pkg/apis/agones/v1/fuzzer"
	//"k8s.io/apimachinery/pkg/runtime/schema"
	//"k8s.io/apimachinery/pkg/util/sets"
)

func TestRoundTripTypes(t *testing.T) {
	//fuzzer.MergeFuzzerFuncs(metafuzzer.Funcs, agones
	roundtrip.RoundTripTestForAPIGroup(t, Install, agonesfuzzer.Funcs)
	/*
	roundtrip.RoundTripProtobufTestForAPIGroup(t, Install, agonesfuzzer.Funcs)
	sch := runtime.NewScheme()
	Install(sch)
	roundtrip.RoundTripProtobufTestForScheme(t, sch, agonesfuzzer.Funcs)
	fmt.Println("Groups", groupsFromScheme(sch))
	fmt.Println(runtime.APIVersionInternal)
	for _, group := range groupsFromScheme(sch) {
		t.Logf("starting group %q", group)
		internalVersion := schema.GroupVersion{Group: group, Version: runtime.APIVersionInternal}
		internalKindToGoType := sch.KnownTypes(internalVersion)

		for kind := range internalKindToGoType {
			fmt.Println(kind)
			
			/*
			if globalNonRoundTrippableTypes.Has(kind) {
				continue
			}* /
			internalGVK := internalVersion.WithKind(kind)
			fmt.Println(internalGVK)
			//roundTripSpecificKind(t, internalGVK, sch, codecFactory, fuzzer, nonRoundTrippableTypes, skipProtobuf)
		}

		t.Logf("finished group %q", group)
	}
	*/
}
/*
func groupsFromScheme(scheme *runtime.Scheme) []string {
	ret := sets.String{}
	for gvk := range scheme.AllKnownTypes() {
		ret.Insert(gvk.Group)
	}
	return ret.List()
}
*/