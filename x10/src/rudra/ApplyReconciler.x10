/**
 * ApplyReconciler.x10
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
