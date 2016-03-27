/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.util.concurrent.AtomicBoolean;
import x10.io.Unserializable;
import x10.compiler.Pinned;

import rudra.util.Logger;
import rudra.util.MergingMonitor;
import rudra.util.Monitor;
import rudra.util.Unit;
import rudra.util.SwapBuffer;

@Pinned class ApplyReconciler(size:Long, maxMB: UInt, nLearner:NativeLearner, 
                              desiredR:Int, reducer:AtLeastRAllReducer, 
                              mmPLH:PlaceLocalHandle[MergingMonitor],
                              logger:Logger) implements Unserializable {

    var timeStamp:UInt = 0un; // incremented each time an all reduce produces non zero load
    // TODO: double buffer to avoid wait on lock..?? Debatable. You want freshest weights.
    val monitor = new Monitor();
    var sizeMB:UInt = 0un; // #MB processed since last pickup
    var weightTimeStamp:UInt=0un;  // accumulate the weights, used by learner to figure out which epoch it is in
    def acceptNWGradient(rg:TimedGradient) {
        monitor.atomicBlock(()=> {
                weightTimeStamp=rg.timeStamp;
                val multiplier = 1.0f / rg.loadSize();
                nLearner.acceptGradients(rg.grad, multiplier);
                sizeMB += rg.loadSize();
                Unit()
            });
        logger.info(()=>"Reconciler:<- Network, weights updated with " + rg); 
        rg.setLoadSize(0un);
    }
    def fillInWeights(w:TimedWeight):void {
        monitor.atomicBlock(()=> {
                if (w.timeStamp < weightTimeStamp) {
                    nLearner.serializeWeights(w.weight);
                    w.setLoadSize(sizeMB);
                    w.timeStamp=weightTimeStamp;
                    sizeMB=0un;
                }
                Unit()
            });
    }

    def run(fromLearner:SwapBuffer[TimedGradient], done:AtomicBoolean) {
        logger.info(()=>"Reconciler: started.");
        val dest  = new TimedGradient(size); 
        var compG:TimedGradient  = new TimedGradient(size); 
        var totalMBReceived:UInt = 0un;
        reducer.initialize(size);
        val mm = mmPLH(); // local merging monitor
        while (totalMBReceived < maxMB) { 
            var readyToReduce:Boolean = false;
            if (desiredR > 0 ) {
                logger.info(()=>"Reconciler: awaiting input.");
                val newPhase = mm.await(timeStamp);
                logger.info(()=>"Reconciler: awakened with phase=" + newPhase);
                readyToReduce = newPhase == timeStamp+1un;
            }
            assert compG.loadSize()==0un : "Reconciler: " + compG + " should have zero size.";
            val tmp = fromLearner.get(compG);
            val received = tmp!= compG;
            compG = tmp;
            if (received) logger.info(()=>"Reconciler:<- Learner " + tmp);
            reducer.run(readyToReduce, timeStamp, compG, mmPLH, dest); // may reduce
            val includedMB = dest.loadSize();
            totalMBReceived += includedMB;
            if (includedMB > 0un) { 
                timeStamp  = dest.timeStamp;
                acceptNWGradient(dest);
            }// includeMB>0
        } // while
        logger.info(()=>"Reconciler: Exited main loop, terminating. timeStamp=" + timeStamp);
        logger.notify(()=> "" + reducer.allreduceTimer);
        done.set(true);
    } //reconciler
}
// vim: shiftwidth=4:tabstop=4:expandtab
