/**
 *
 * ImmedReconciler.x10
 *
 * Rudra Distributed Learning Platform
 *
 * Copyright (c) IBM Corporation 2016
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * 3. Neither the name of Rudra nor the names of its contributors may be used
 *   to endorse or promote products derived from this software without specific
 *   prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
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
