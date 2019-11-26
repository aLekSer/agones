package fleetautoscaler

import (
	agonesv1 "agones.dev/agones/pkg/apis/agones/v1"
	autoscalingv1 "agones.dev/agones/pkg/apis/autoscaling/v1"
	"agones.dev/agones/pkg/fleetautoscalers"
	"fmt"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

// How to use 
// go-fuzz-build && go-fuzz
func Fuzz(data []byte) int {
	fas, f := defaultFixtures()
	b := fas.Spec.Policy.Buffer

	if len(data) > 6 {
		if data[0] < 100 {
			b.BufferSize = intstr.FromString(fmt.Sprintf("%f%%", float64(data[0])/10.))
		} else {
			b.BufferSize = intstr.FromInt(int( data[0] - 100))
		}
		b.MinReplicas = int32(data[6])
		b.MaxReplicas = int32(data[1])
		f.Spec.Replicas = int32(data[2])
		f.Status.Replicas = int32(data[3])
		f.Status.AllocatedReplicas = int32(data[4])
		f.Status.ReadyReplicas = int32(data[5])
		if f.Status.AllocatedReplicas  > f.Spec.Replicas  {
			return -1
		}
		if f.Status.AllocatedReplicas  > f.Status.Replicas {
			return -1
		}
		if  b.MinReplicas  > b.MaxReplicas {
			return -1 
		}
		target, limited, err := fleetautoscalers.ApplyBufferPolicy(b, f)
		if err != nil {
			if target != f.Status.Replicas {
				panic("something bad have happened")
			}
		}
		if target < f.Status.AllocatedReplicas {
			panic("something bad have happened")
		}
		if limited  {
			if target != b.MinReplicas &&  target !=  b.MaxReplicas {
				panic("something bad have happened")
			}
		} else if b.BufferSize.Type == intstr.Int {
			if target != f.Status.AllocatedReplicas + int32(b.BufferSize.IntValue()) {
				panic("something bad have happened")
			}
		} else {
			if data[0] != 0  && ((float64(target) - float64(f.Status.AllocatedReplicas)) / float64(target)) - float64(data[0])/10. > 0.02 {
				panic("too big difference")
			}
		}
	} else {
		return -1
	}
	return 0
}

// What should happen if we have number of Allocated Replicas > number of maxReplicas in FleetAutoscaler?


func defaultFixtures() (*autoscalingv1.FleetAutoscaler, *agonesv1.Fleet) {
	f := &agonesv1.Fleet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "fleet-1",
			Namespace: "default",
			UID:       "1234",
		},
		Spec: agonesv1.FleetSpec{
			Replicas: 8,
			Template: agonesv1.GameServerTemplateSpec{},
		},
		Status: agonesv1.FleetStatus{
			Replicas:          5,
			ReadyReplicas:     3,
			ReservedReplicas:  3,
			AllocatedReplicas: 2,
		},
	}

	fas := &autoscalingv1.FleetAutoscaler{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "fas-1",
			Namespace: "default",
		},
		Spec: autoscalingv1.FleetAutoscalerSpec{
			FleetName: f.ObjectMeta.Name,
			Policy: autoscalingv1.FleetAutoscalerPolicy{
				Type: autoscalingv1.BufferPolicyType,
				Buffer: &autoscalingv1.BufferPolicy{
					BufferSize:  intstr.FromInt(5),
					MaxReplicas: 100,
				},
			},
		},
	}

	return fas, f
}