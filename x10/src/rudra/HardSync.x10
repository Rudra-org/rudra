/**
 * HardSync.x10
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
import rudra.util.Timer;

import x10.util.Team;

/** HardSync implements SGD in parallel by dividing the mini batch evenly across
    all learners, and allreducing the gradients. All learners see the same
    sequence of weights, and weights(t+1) is built from gradients computed
    from weights(t). 
    @author vj
 */
public class HardSync(noTest:Boolean, weightsFile:String, lr:Int) extends Learner {
    public def this(config:RudraConfig, confName:String, noTest:Boolean, weightsFile: String,
                    team:Team, logger:Logger, lr:Int, lt:Int, solverType:String,
                    nLearner:NativeLearner) {
        super(config, confName, 0un, nLearner, team, logger, lt, solverType);
        property(noTest, weightsFile, lr);
    }
    val trainTimer     = new Timer("Training Time:");
    val allreduceTimer = new Timer("Reduce Time:");
    val weightTimer    = new Timer("Weight Update Time:");
    def run() {
        logger.info(()=>"Learner: started.");
        val compG = new TimedGradient(size); 
        compG.timeStamp = UInt.MAX_VALUE;
        val testManager = (here.id==0) ? new TestManager(config, nLearner, noTest, solverType, lt) : null;
        if (here.id==0) testManager.initialize();
        val dest = new TimedGradient(size);
        initWeightsIfNeeded(weightsFile); 
        val loggerRec = new Logger(lr);
        var currentEpoch:UInt = 0un;
        var totalMBProcessed:UInt = 0un;
        while (totalMBProcessed < maxMB) {
            computeGradient(compG);
            allreduceTimer.tic();
            team.allreduce(compG.grad, 0, dest.grad, 0, size, Team.ADD);
            allreduceTimer.toc();
            compG.setLoadSize(0un);
            timeStamp++;
            dest.timeStamp=timeStamp;
            if (here.id==0) 
               loggerRec.notify(()=>"Reconciler: <- Network "  
                             + dest + "(" + allreduceTimer.lastDurationMillis()+" ms)");
            weightTimer.tic();
            acceptNWGradient(dest);
            totalMBProcessed += dest.loadSize();
            weightTimer.toc();
            // follow learning rate schedule given in config file
            if ((totalMBProcessed / mbPerEpoch) > currentEpoch) {
                val newLearningRate = config.lrMult(++currentEpoch);
                loggerRec.notify(()=> "Reconciler: updating learning rate to "+ newLearningRate);
                nLearner.setLearningRateMultiplier(newLearningRate);
                if (testManager != null) testManager.touch(dest.loadSize());
            }
        } // while !done
        if (testManager != null) testManager.finalize();
        logger.info(()=>"Learner: Exited main loop.");
        if (here.id==0) {
            logger.notify(()=> "" + cgTimer);
            logger.notify(()=> "" + allreduceTimer);
            logger.notify(()=> "" + weightTimer);
        }
    } //run
}
// vim: shiftwidth=4:tabstop=4:expandtab
