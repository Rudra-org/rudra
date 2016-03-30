/**
 * TestManager.x10
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

import rudra.util.BlockingRXchgBuffer;
import rudra.util.Logger;
import rudra.util.Timer;

/**
 * The TestManager runs at Place 0 (alongside either a parameter server or a
 * learner) and sends weights to the Tester, which performs testing at
 * Place(P-1).
 */
public class TestManager(config:RudraConfig, nLearner:NativeLearner, noTest:Boolean, solverType:String, lt:Int) {
    val mbPerEpoch = config.mbPerEpoch();
    val toTester = new BlockingRXchgBuffer[TimedWeightWRuntime](new TimedWeightWRuntime(nLearner.getNetworkSize()));
    var weights:TimedWeightWRuntime= new TimedWeightWRuntime(nLearner.getNetworkSize());
    var totalMBProcessed:UInt = 0un;
    var epoch:UInt = 0un;
    var epochStartTime:Long = 0;
    var lastTested:UInt=0un;
    val logger = new Logger(lt);

    def initialize() {
        if (noTest) return;
        val testerPlace = Place.places()(Place.numPlaces()-1);
        async new Tester(config, testerPlace, new Logger(lt), solverType).run(nLearner.getNetworkSize(), toTester);
        epochStartTime = System.nanoTime();
    }

    def touch(loadSize:Long) {
        touch(null);
        totalMBProcessed += loadSize;
    }

    def touch(tw:TimedWeight):void {
        if (noTest) return;
        if (tw != null) totalMBProcessed += tw.loadSize;
        // Called by place 0 learner or PS: Test for epoch transition.
        // Try to get a Tester to run with these weights
        val ts = (tw==null) ? totalMBProcessed : tw.timeStamp();
        val thisEpoch = ts/mbPerEpoch;
        if (thisEpoch <= epoch) return;
        val oldEpoch = epoch;
        val epochEndTime = System.nanoTime();
        val epochRuntime = epochEndTime-epochStartTime;
        epoch = thisEpoch;
        epochStartTime=epochEndTime;
        if (tw == null) nLearner.serializeWeights(weights.weightRail());
        else  Rail.copy(tw.weightRail(), weights.weightRail());
        weights.setTimeStamp(oldEpoch);
        weights.setRuntime(epochRuntime/(1000*1000)); // in ms.
        val w = weights;
        logger.notify(()=>"TestManager: Pinging tester with "  + w);
        weights = toTester.put(weights);
        if (weights != w) lastTested=oldEpoch;
        logger.notify(()=>"TestManager: Tester "+(weights!=w?"accepted " : "did not accept ")+w);
    }

    def finalize() {
        if (!noTest) {
            if (lastTested < epoch) { // make sure u test the last weights
                weights.timeStamp=epoch;
                val epochEndTime = System.nanoTime();
                val epochRuntime = epochEndTime-epochStartTime;
                weights.setRuntime(epochRuntime/(1000*1000)); // in ms.
                nLearner.serializeWeights(weights.weight);
                toTester.put(weights);
            }
            toTester.put(TimedWeightWRuntime.POISON);
        }
    }
} // TestManager
