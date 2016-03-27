/**
 * HardBufferedReconciler.x10
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
