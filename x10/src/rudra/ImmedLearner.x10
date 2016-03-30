/**
 * ImmedLearner.x10
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

import rudra.util.Logger;
import rudra.util.SwapBuffer;

import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.Lock;
import x10.util.Team;


public class ImmedLearner(noTest:Boolean) extends Learner {

    public def this(config:RudraConfig, confName:String, noTest:Boolean, spread:UInt,
                    nLearner:NativeLearner, 
                    team:Team, logger:Logger, lt:Int, solverType:String) {
        super(config, confName, spread, nLearner, team, logger, lt, solverType);
        property(noTest);
    }

    // method called by reconciler thread.
    val lock = new Lock();

    def setTimeStamp(ts:UInt):void {
        try {
            lock.lock();
            timeStamp = ts;
        } finally {
            lock.unlock();
        }
    }
    def acceptGradientFromReconciler(g:TimedGradient) {
        val includeMB = g.loadSize();
        try {
            lock.lock();
            timeStamp = g.timeStamp;
        } finally {
            lock.unlock();
        }
        acceptGradients(g.grad, includeMB);
        logger.info(()=>"Reconciler: delivered network gradient " + g + " to learner.");
    }
    def run(fromLearner:SwapBuffer[TimedGradient], done:AtomicBoolean) {
        logger.info(()=>"Learner: started.");
        var compG:TimedGradient = new TimedGradient(size); 
        compG.timeStamp = UInt.MAX_VALUE;
        val testManager = (here.id==0) ? new TestManager(config, this.nLearner, noTest, solverType, lt) : null;
        if (testManager != null) testManager.initialize();
        val currentWeight = new TimedWeight(networkSize);
        initWeights();
        while (! done.get()) {
            computeGradient(compG);
            val loadSize = compG.loadSize();
            compG=deliverGradient(compG, fromLearner);
            // the reconciler will come in and update weights asynchronously
            if (testManager != null) testManager.touch(loadSize);
        } // while !done

        if (testManager != null) testManager.finalize();
        logger.info(()=>"Learner: Exited main loop.");
    } //learner

}
// vim: shiftwidth=4:tabstop=4:expandtab

