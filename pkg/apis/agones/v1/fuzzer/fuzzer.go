
package fuzzer

import (

	"fmt" 

	fuzz "github.com/google/gofuzz"

	agonesv1 "agones.dev/agones/pkg/apis/agones/v1"

	runtimeserializer "k8s.io/apimachinery/pkg/runtime/serializer"
)

// Funcs returns the fuzzer functions for the agones api group.
var Funcs = func(codecs runtimeserializer.CodecFactory) []interface{} {
	return []interface{}{
		func(s *agonesv1.GameServerSpec, c fuzz.Continue) {
			c.FuzzNoCustom(s) // fuzz first without calling this function again

			// avoid empty Toppings because that is defaulted
			/*
			if len(agonesv1.Toppings) == 0 {
				s.Toppings = []restaurant.PizzaTopping{
					{"salami", 1},
					{"mozzarella", 1},
					{"tomato", 1},
				}
			}
			*/
			s.Container = "gcr.io/agones-image/sdk-server:0.3"
			s.Ports = []agonesv1.GameServerPort{agonesv1.GameServerPort{"123", "Dynamic", 777,1251,"UDP"},
				agonesv1.GameServerPort{"123", "Dynamic", 777,1251,"UDP"}}
			fmt.Printf("%+v", s)

			/*
			seen := map[string]bool{}
				// make quantity strictly positive and of reasonable size
				//s.Toppings[i].Quantity = 1 + c.Intn(10)

				// remove duplicates
				for {
					if !seen[s.ObjectMeta.Name] {
						break
					}
					s.ObjectMeta.Name = c.RandString()
				}
				seen[s.ObjectMeta.Name] = true
				*/
		},
		func(s *agonesv1.GameServer, c fuzz.Continue) {
			c.FuzzNoCustom(s) // fuzz first without calling this function again
			fmt.Printf("GS %+v", s)
		},
		func(s *agonesv1.GameServerSetSpec, c fuzz.Continue) {
			c.FuzzNoCustom(s) // fuzz first without calling this function again
			fmt.Printf("GSSS %+v", s)
		},
		func(s *agonesv1.FleetSpec, c fuzz.Continue) {
			c.FuzzNoCustom(s) // fuzz first without calling this function again
			fmt.Printf("Fleet %+v", s)
		},
	}
}