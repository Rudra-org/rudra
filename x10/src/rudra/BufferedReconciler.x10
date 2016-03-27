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

    val allreduceTimer=new Timer("Allreduce Time:");
    def run(fromLearner:SwapBuffer[TimedGradient], 
            toLearner:SwapBuffer[TimedGradient], done:AtomicBoolean) {
        logger.info(()=>"Reconciler: started.");

        var dest:TimedGradient  = new TimedGradient(size); 
        var compG:TimedGradient  = new TimedGradient(size); 
        var totalMBReceived:UInt = 0un;

        while (totalMBReceived < maxMB) { 

            compg = fromLearner.get(compG);
            allreduceTimer.tic();
            team.allreduce(compG.grad, 0, dest.grad, 0, size, Team.ADD);
            timeStamp++;
            dest.timeStamp=timeStamp;
            allreduceTimer.toc();
            if (here.id==0) 
               logger.notify(()=>"Reconciler: <- Network "  
                             + dest + "(" + allreduceTimer.lastDurationMillis()+" ms)");

            val includedMB = dest.loadSize();
            totalMBReceived += dest.load
            dest=toLearner.put(dest);
            compG.setLoadSize(0un);

        } // while
        logger.info(()=>"Reconciler: Exited main loop, terminating. timeStamp=" + timeStamp);
        logger.notify(()=> "" + reducer.allreduceTimer);
        done.set(true);
    } //reconciler
}
// vim: shiftwidth=4:tabstop=4:expandtab
