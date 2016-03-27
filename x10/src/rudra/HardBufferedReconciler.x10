/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.compiler.Pinned;
import x10.io.Unserializable;
import x10.util.Team;
import x10.util.concurrent.AtomicBoolean;

import rudra.util.Logger;
import rudra.util.SwapBuffer;
import rudra.util.Timer;

@Pinned class HardBufferedReconciler(config:RudraConfig, size:Long, logger:Logger, team:Team) 
    implements Unserializable {

    var timeStamp:UInt = 0un; 
    var sizeMB:UInt = 0un; // #MB processed since last pickup

    val allreduceTimer=new Timer("Allreduce Time:");
    def run(fromLearner:SwapBuffer[TimedGradient], 
            toLearner:SwapBuffer[TimedGradient], done:AtomicBoolean) {
        logger.info(()=>"Reconciler: started.");

        var dest:TimedGradient  = new TimedGradient(size); 
        var compG:TimedGradient  = new TimedGradient(size); 
        var totalMBReceived:UInt = 0un;

        val numEpochs = config.numEpochs;
        val numTrainSamples = config.numTrainSamples;
        val mbPerEpoch = config.mbPerEpoch();
        val maxMB = config.maxMB();

        while (totalMBReceived < maxMB) { 
            compG = fromLearner.get(compG); // blocking
            allreduceTimer.tic();
            team.allreduce(compG.grad, 0, dest.grad, 0, dest.grad.size, Team.ADD);
            allreduceTimer.toc();
            timeStamp++;
            dest.timeStamp=timeStamp;
            if (here.id==0) {
                val d = dest;
                logger.notify(()=>"Reconciler: <- Network "  
                              + d + "(" + allreduceTimer.lastDurationMillis()+" ms)");
            }
            totalMBReceived += dest.loadSize();
            dest=toLearner.put(dest); // nonblocking
            compG.setLoadSize(0un);
        } // while
        logger.info(()=>"Reconciler: Exited main loop, terminating. timeStamp=" + timeStamp);
        logger.notify(()=> "" + allreduceTimer);
        done.set(true);
    } //reconciler
}
// vim: shiftwidth=4:tabstop=4:expandtab
