/**
 * HardBufferedLearner.x10
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
import rudra.util.SwapBuffer;

import x10.util.concurrent.AtomicBoolean;
import x10.util.Team;

public class HardBufferedLearner(noTest:Boolean, 
                                 weightsFile:String) extends Learner {

    public def this(config:RudraConfig, confName:String, noTest:Boolean, 
                    weightsFile:String, 
                    team:Team, logger:Logger, lt:Int, solverType:String,
                    nLearner:NativeLearner) {
        super(config, confName, 0un, nLearner, team, logger, lt, solverType);
        property(noTest, weightsFile);
    }
    val trainTimer = new Timer("Training Time:");
    val weightTimer = new Timer("Weight Update Time:");

    def run(fromLearner:SwapBuffer[TimedGradient], 
            toLearner:SwapBuffer[TimedGradient], done:AtomicBoolean) {
        logger.info(()=>"Learner: started.");
        var compG:TimedGradient = new TimedGradient(size); 
        compG.timeStamp = UInt.MAX_VALUE;
        val testManager = here.id==0? (this as Learner).new TestManager(config, noTest, solverType) : null;
        if (here.id==0) testManager.initialize();
        epochStartTime= System.nanoTime();
        initWeightsIfNeeded(weightsFile);
        var dest:TimedGradient = new TimedGradient(size); 
        computeGradient(compG);         
        compG=fromLearner.put(compG);
        // first time around, no gradient to receive from network.
        while (!done.get()) {
            computeGradient(compG);         
            compG=fromLearner.put(compG);

            dest=toLearner.get(dest);
            acceptNWGradient(dest);

            if (testManager != null) testManager.touch();
        } // while !done

        if (testManager != null) testManager.finalize();
        logger.info(()=>"Learner: Exited main loop.");
        if (here.id==0) logger.notify(()=> "" + cgTimer);
    } //learner

}
// vim: shiftwidth=4:tabstop=4:expandtab
