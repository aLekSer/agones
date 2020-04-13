// Copyright 2018 Google LLC All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package metrics

import (
	"context"
	"strconv"
	"strings"
	"sync"
	"time"

	agonesv1 "agones.dev/agones/pkg/apis/agones/v1"
	autoscalingv1 "agones.dev/agones/pkg/apis/autoscaling/v1"
	"agones.dev/agones/pkg/client/clientset/versioned"
	"agones.dev/agones/pkg/client/informers/externalversions"
	listerv1 "agones.dev/agones/pkg/client/listers/agones/v1"
	"agones.dev/agones/pkg/util/runtime"
	lru "github.com/hashicorp/golang-lru"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"go.opencensus.io/stats"
	"go.opencensus.io/tag"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	v1 "k8s.io/client-go/listers/core/v1"
	"k8s.io/client-go/tools/cache"
)

const noneValue = "none"

var (
	// MetricResyncPeriod is the interval to re-synchronize metrics based on indexed cache.
	MetricResyncPeriod = time.Second * 15
)

func init() {
	registerViews()
}

// Controller is a metrics controller collecting Agones state metrics
type Controller struct {
	logger           *logrus.Entry
	gameServerLister listerv1.GameServerLister
	nodeLister       v1.NodeLister
	gameServerSynced cache.InformerSynced
	fleetSynced      cache.InformerSynced
	fasSynced        cache.InformerSynced
	nodeSynced       cache.InformerSynced
	lock             sync.Mutex
	stateLock        sync.Mutex
	gsCount          GameServerCount
	faCount          map[string]int64
}

// NewController returns a new metrics controller
func NewController(
	kubeClient kubernetes.Interface,
	agonesClient versioned.Interface,
	kubeInformerFactory informers.SharedInformerFactory,
	agonesInformerFactory externalversions.SharedInformerFactory) *Controller {

	gameServer := agonesInformerFactory.Agones().V1().GameServers()
	gsInformer := gameServer.Informer()

	fleets := agonesInformerFactory.Agones().V1().Fleets()
	fInformer := fleets.Informer()
	fas := agonesInformerFactory.Autoscaling().V1().FleetAutoscalers()
	fasInformer := fas.Informer()
	node := kubeInformerFactory.Core().V1().Nodes()
	nodeInformer := node.Informer()
	lruCache, err := lru.New(1 << 24)
	if err != nil {
		logger.Error("Could not create LRU cache ", err)
	}
	GameServerStateLastChange = lruCache

	c := &Controller{
		gameServerLister: gameServer.Lister(),
		nodeLister:       node.Lister(),
		gameServerSynced: gsInformer.HasSynced,
		fleetSynced:      fInformer.HasSynced,
		fasSynced:        fasInformer.HasSynced,
		nodeSynced:       nodeInformer.HasSynced,
		gsCount:          GameServerCount{},
		faCount:          map[string]int64{},
	}

	c.logger = runtime.NewLoggerWithType(c)

	fInformer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: c.recordFleetChanges,
		UpdateFunc: func(old, next interface{}) {
			c.recordFleetChanges(next)
		},
		DeleteFunc: c.recordFleetDeletion,
	})

	fasInformer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(added interface{}) {
			c.recordFleetAutoScalerChanges(nil, added)
		},
		UpdateFunc: c.recordFleetAutoScalerChanges,
		DeleteFunc: c.recordFleetAutoScalerDeletion,
	})

	gsInformer.AddEventHandlerWithResyncPeriod(cache.ResourceEventHandlerFuncs{
		UpdateFunc: c.recordGameServerStatusChanges,
	}, 0)

	return c
}

func (c *Controller) recordFleetAutoScalerChanges(old, next interface{}) {

	fas, ok := next.(*autoscalingv1.FleetAutoscaler)
	if !ok {
		return
	}

	// we looking for fleet name changes if that happens we need to reset
	// metrics for the old fas.
	if old != nil {
		if oldFas, ok := old.(*autoscalingv1.FleetAutoscaler); ok &&
			oldFas.Spec.FleetName != fas.Spec.FleetName {
			c.recordFleetAutoScalerDeletion(old)
		}
	}

	// fleet autoscaler has been deleted last value should be 0
	if fas.DeletionTimestamp != nil {
		c.recordFleetAutoScalerDeletion(fas)
		return
	}

	ctx, _ := tag.New(context.Background(), tag.Upsert(keyName, fas.Name),
		tag.Upsert(keyFleetName, fas.Spec.FleetName), tag.Upsert(keyNamespace, fas.Namespace))

	ableToScale := 0
	limited := 0
	if fas.Status.AbleToScale {
		ableToScale = 1
	}
	if fas.Status.ScalingLimited {
		limited = 1
	}
	// recording status
	stats.Record(ctx,
		fasCurrentReplicasStats.M(int64(fas.Status.CurrentReplicas)),
		fasDesiredReplicasStats.M(int64(fas.Status.DesiredReplicas)),
		fasAbleToScaleStats.M(int64(ableToScale)),
		fasLimitedStats.M(int64(limited)))

	// recording buffer policy
	if fas.Spec.Policy.Buffer != nil {
		// recording limits
		recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "max")},
			fasBufferLimitsCountStats.M(int64(fas.Spec.Policy.Buffer.MaxReplicas)))
		recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "min")},
			fasBufferLimitsCountStats.M(int64(fas.Spec.Policy.Buffer.MinReplicas)))

		// recording size
		if fas.Spec.Policy.Buffer.BufferSize.Type == intstr.String {
			// as percentage
			sizeString := fas.Spec.Policy.Buffer.BufferSize.StrVal
			if sizeString != "" {
				if size, err := strconv.Atoi(sizeString[:len(sizeString)-1]); err == nil {
					recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "percentage")},
						fasBufferSizeStats.M(int64(size)))
				}
			}
		} else {
			// as count
			recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "count")},
				fasBufferSizeStats.M(int64(fas.Spec.Policy.Buffer.BufferSize.IntVal)))
		}
	}
}

func (c *Controller) recordFleetAutoScalerDeletion(obj interface{}) {
	fas, ok := obj.(*autoscalingv1.FleetAutoscaler)
	if !ok {
		return
	}
	ctx, _ := tag.New(context.Background(), tag.Upsert(keyName, fas.Name),
		tag.Upsert(keyFleetName, fas.Spec.FleetName), tag.Upsert(keyNamespace, fas.Namespace))

	// recording status
	stats.Record(ctx,
		fasCurrentReplicasStats.M(int64(0)),
		fasDesiredReplicasStats.M(int64(0)),
		fasAbleToScaleStats.M(int64(0)),
		fasLimitedStats.M(int64(0)))
}

func (c *Controller) recordFleetChanges(obj interface{}) {
	f, ok := obj.(*agonesv1.Fleet)
	if !ok {
		return
	}

	// fleet has been deleted last value should be 0
	if f.DeletionTimestamp != nil {
		c.recordFleetDeletion(f)
		return
	}

	c.recordFleetReplicas(f.Name, f.Namespace, f.Status.Replicas, f.Status.AllocatedReplicas,
		f.Status.ReadyReplicas, f.Spec.Replicas)
}

func (c *Controller) recordFleetDeletion(obj interface{}) {
	f, ok := obj.(*agonesv1.Fleet)
	if !ok {
		return
	}

	c.recordFleetReplicas(f.Name, f.Namespace, 0, 0, 0, 0)
}

func (c *Controller) recordFleetReplicas(fleetName, fleetNamespace string, total, allocated, ready, desired int32) {

	ctx, _ := tag.New(context.Background(), tag.Upsert(keyName, fleetName), tag.Upsert(keyNamespace, fleetNamespace))

	recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "total")},
		fleetsReplicasCountStats.M(int64(total)))
	recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "allocated")},
		fleetsReplicasCountStats.M(int64(allocated)))
	recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "ready")},
		fleetsReplicasCountStats.M(int64(ready)))
	recordWithTags(ctx, []tag.Mutator{tag.Upsert(keyType, "desired")},
		fleetsReplicasCountStats.M(int64(desired)))
}

// recordGameServerStatusChanged records gameserver status changes, however since it's based
// on cache events some events might collapsed and not appear, for example transition state
// like creating, port allocation, could be skipped.
// This is still very useful for final state, like READY, ERROR and since this is a counter
// (as opposed to gauge) you can aggregate using a rate, let's say how many gameserver are failing
// per second.
// Addition to the cache are not handled, otherwise resync would make metrics inaccurate by doubling
// current gameservers states.
func (c *Controller) recordGameServerStatusChanges(old, next interface{}) {
	newGs, ok := next.(*agonesv1.GameServer)
	if !ok {
		return
	}
	oldGs, ok := old.(*agonesv1.GameServer)
	if !ok {
		return
	}
	if newGs.Status.State != oldGs.Status.State {
		fleetName := newGs.Labels[agonesv1.FleetNameLabel]
		if fleetName == "" {
			fleetName = noneValue
		}
		recordWithTags(context.Background(), []tag.Mutator{tag.Upsert(keyType, string(newGs.Status.State)),
			tag.Upsert(keyFleetName, fleetName), tag.Upsert(keyNamespace, newGs.GetNamespace())}, gameServerTotalStats.M(1))
		if newGs.Status.State == agonesv1.GameServerStateReady {
			diff := time.Now().Sub(newGs.ObjectMeta.CreationTimestamp.Local()).Seconds()
			c.logger.Info("Time taken to become ready", diff)
			recordWithTags(context.Background(), []tag.Mutator{tag.Upsert(keyType, string(newGs.Status.State)),
				tag.Upsert(keyFleetName, fleetName)}, gsReadyDuration.M(diff*1000.))
			tag.Upsert(keyFleetName, fleetName)}, gameServerTotalStats.M(1))

		// Calculate the duration from the start of the GameServer
		c.stateLock.Lock()
		defer c.stateLock.Unlock()
		err := calcDuration(newGs, oldGs)
		if err != nil {
			c.logger.Info(err.Error())
		}
	}
}

func calcDuration(newGs, oldGs *agonesv1.GameServer) error {
	fleetName := newGs.Labels[agonesv1.FleetNameLabel]
	diff := time.Now().Sub(newGs.ObjectMeta.CreationTimestamp.Local()).Seconds()
	key := newGs.ObjectMeta.Name + "/" + string(newGs.Status.State)
	oldKey := oldGs.ObjectMeta.Name + "/" + string(oldGs.Status.State)
	if !GameServerStateLastChange.Contains(key) {
		GameServerStateLastChange.Add(key, diff)
		recordWithTags(context.Background(), []tag.Mutator{tag.Upsert(keyType, string(newGs.Status.State)),
			tag.Upsert(keyFleetName, fleetName)}, gsStateDuration.M(diff*1000.))
	} else {
		val, ok := GameServerStateLastChange.Get(key)
		if !ok {
			return errors.New("Could not find expected key")
		}
		duration := diff - val.(float64)
		recordWithTags(context.Background(), []tag.Mutator{tag.Upsert(keyType, string(oldGs.Status.State)),
			tag.Upsert(keyFleetName, fleetName)}, gsStateDuration.M(duration*1000.))
		GameServerStateLastChange.Add(key, diff)
		GameServerStateLastChange.Remove(oldKey)
	}
	if newGs.Status.State == agonesv1.GameServerStateShutdown {
		GameServerStateLastChange.Remove(oldKey)
	}
	return nil
}

// Run the Metrics controller. Will block until stop is closed.
// Collect metrics via cache changes and parse the cache periodically to record resource counts.
func (c *Controller) Run(workers int, stop <-chan struct{}) error {
	c.logger.Info("Wait for cache sync")
	if !cache.WaitForCacheSync(stop, c.gameServerSynced, c.fleetSynced, c.fasSynced) {
		return errors.New("failed to wait for caches to sync")
	}
	wait.Until(c.collect, MetricResyncPeriod, stop)
	return nil
}

// collect all metrics that are not event-based.
// this is fired periodically.
func (c *Controller) collect() {
	c.lock.Lock()
	defer c.lock.Unlock()
	c.collectGameServerCounts()
	c.collectNodeCounts()
}

// collects gameservers count by going through our informer cache
// this not meant to be called concurrently
func (c *Controller) collectGameServerCounts() {

	gameservers, err := c.gameServerLister.List(labels.Everything())
	if err != nil {
		c.logger.WithError(err).Warn("failed listing gameservers")
		return
	}

	if err := c.gsCount.record(gameservers); err != nil {
		c.logger.WithError(err).Warn("error while recoding stats")
	}
}

// collectNodeCounts count gameservers per node using informer cache.
func (c *Controller) collectNodeCounts() {
	gsPerNodes := map[string]int32{}

	gameservers, err := c.gameServerLister.List(labels.Everything())
	if err != nil {
		c.logger.WithError(err).Warn("failed listing gameservers")
		return
	}
	for _, gs := range gameservers {
		if gs.Status.NodeName != "" {
			gsPerNodes[gs.Status.NodeName]++
		}
	}

	nodes, err := c.nodeLister.List(labels.Everything())
	if err != nil {
		c.logger.WithError(err).Warn("failed listing gameservers")
		return
	}

	nodes = removeSystemNodes(nodes)
	recordWithTags(context.Background(), []tag.Mutator{tag.Insert(keyEmpty, "true")},
		nodesCountStats.M(int64(len(nodes)-len(gsPerNodes))))
	recordWithTags(context.Background(), []tag.Mutator{tag.Insert(keyEmpty, "false")},
		nodesCountStats.M(int64(len(gsPerNodes))))

	for _, node := range nodes {
		stats.Record(context.Background(), gsPerNodesCountStats.M(int64(gsPerNodes[node.Name])))
	}

}

func removeSystemNodes(nodes []*corev1.Node) []*corev1.Node {
	var result []*corev1.Node

	for _, n := range nodes {
		if !isSystemNode(n) {
			result = append(result, n)
		}
	}

	return result
}

// isSystemNode determines if a node is a system node, by checking if it has any taints starting with "agones.dev/"
func isSystemNode(n *corev1.Node) bool {
	for _, t := range n.Spec.Taints {
		if strings.HasPrefix(t.Key, "agones.dev/") {
			return true
		}
	}

	return false
}
