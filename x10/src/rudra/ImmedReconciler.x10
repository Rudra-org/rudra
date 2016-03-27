/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.util.concurrent.AtomicBoolean;

import rudra.util.SwapBuffer;
import rudra.util.Logger;

class ImmedReconciler(config:RudraConfig, size:Long, learner:ImmedLearner, 
                      reducer:AtLeastRAllReducer, logger:Logger) {
    var timeStamp:UInt = 0un; // incremented each time an all reduce is done

    def run(fromLearner:SwapBuffer[TimedGradient], done:AtomicBoolean) {
        logger.info(()=>"ImmedReconciler: started.");
        val dest  = new TimedGradient(size); 
        var compG:TimedGradient  = new TimedGradient(size); 
        var totalMBReceived:UInt = 0un;
        reducer.initialize(size);
        val numEpochs = config.numEpochs;
        val mbSize = config.mbSize;
        val numTrainSamples = config.numTrainSamples;
        // rounded up to nearest unit, so more MB may be generated than needed.
        val mbPerEpoch = ((numTrainSamples + mbSize - 1) / mbSize) as UInt; 
        val maxMB = numEpochs * mbPerEpoch;
        while (totalMBReceived < maxMB) { 
            compG = fromLearner.get(compG);
            //            reducer.acceptContrib(compG);
            //            reducer.reduceIfPossible(dest, timeStamp);
            val includedMB = dest.loadSize();
            if (includedMB > 0un) { 
                totalMBReceived += includedMB;
                timeStamp++;
                dest.timeStamp = timeStamp;
                learner.acceptGradientFromReconciler(dest);
                dest.setLoadSize(0un);
            }// includeMB>0
        } // while
        logger.info(()=>"Reconciler: Exited main loop, terminating.");
        done.set(true);
    } //reconciler
}
// vim: shiftwidth=4:tabstop=4:expandtab
