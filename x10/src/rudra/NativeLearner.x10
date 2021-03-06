/**
 *
 * NativeLearner.x10
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

import x10.compiler.Native;
import x10.compiler.NativeCPPInclude;
import x10.compiler.NativeRep;

/**
 * Container class for a native learner.
 */
@NativeRep("c++", "rudra::NativeLearner*", "rudra::NativeLearner", null)
public class NativeLearner {

    @Native("c++", "NativeLearner::setLoggingLevel(#level)")
        public static def setLoggingLevel(level:Int):void {}

    @Native("c++", "NativeLearner::setAdaDeltaParams(#rho, #epsilon, #defaultRho, #defaultEpsilon)")
        public static def setAdaDeltaParams(rho:Float, epsilon:Float, 
                                            defaultRho:Float, defaultEpsilon:Float):void {}

    @Native("c++", "NativeLearner::setMeanFile(#fn->c_str())")
    public static def setMeanFile(fn:String):void {}

    @Native("c++", "NativeLearner::setSeed(#id, #seed, #defaultSeed)")
        public static def setSeed(id:Long, seed:Int, defaultSeed:Int):void {}

    @Native("c++", "NativeLearner::setMoM(#mom)")
    public static def setMoM(mom:Float):void {}

    @Native("c++", "NativeLearner::setJobID(#jobID->c_str())")
    public static def setJobID(jobID:String):void {}

    @Native("c++", "NativeLearner::initFromCFGFile(#cfgName->c_str())")
    public static def initFromCFGFile(cfgName:String):void {}

    @Native("c++", "new rudra::NativeLearner(#id)")
        public def this(id:Long){}
        
    @Native("c++", "#this->initNativeLand(#id, #confName->c_str(), #seed, #defaultSeed, #numLearner)")
        public def initNativeLand(id:Long, confName:String, numLearner:Long):void{}

    @Native("c++", "#this->checkpoint(#outputFileName->c_str())")
    public def checkpoint(outputFileName:String):void { }

    @Native("c++", "#this->getNetworkSize()")
    public def getNetworkSize():Long {
        return 0;
    }
        

    @Native("c++", "#this->initAsLearner(#trainData->c_str(), #trainLabels->c_str(), #batchSize, #weightsFile->c_str(), #solverType->c_str())")
    public def initAsLearner(trainData:String, trainLabels:String,
			batchSize:long, weightsFile:String, solverType:String):void { }

    @Native("c++", "#this->initAsTester(#testData->c_str(), #testLabels->c_str(), #batchSize, #solverType->c_str())")
    public def initAsTester(testData:String, testLabels:String,
			batchSize:long, solverType:String):void { }
        
    @Native("c++", "#this->trainMiniBatch()")
    public def trainMiniBatch():float{
            return 0F;
    }

    @Native("c++", "#this->getGradients(#gradients->raw)")
    public def getGradients(gradients:Rail[Float]):void {}

    @Native("c++", "#this->accumulateGradients(#gradients->raw)")
    public def accumulateGradients(gradients:Rail[Float]):void {}

    @Native("c++", "#this->serializeWeights(#weights->raw)")
    public def serializeWeights(weights:Rail[Float]):void {}

    @Native("c++", "#this->deserializeWeights(#weights->raw)")
    public def deserializeWeights(weights:Rail[Float]):void {}

    @Native("c++", "#this->setLearningRateMultiplier(#lrMult)")
    public def setLearningRateMultiplier(lrMult:Float):void { }

    @Native("c++", "#this->acceptGradients(#delta->raw, #multiplier)")
    public def acceptGradients(val delta:Rail[Float], val multiplier:Float):void{}
            
    @Native("c++", "#this->testOneEpoch(#weights->raw)")
        public def testOneEpoch(weights:Rail[Float]):Float {
        return -3.0f;
    }

    /**
     * Free all native-allocated memory.  Afterwards, this object is no
     * longer valid and no further method invocations should be made.
     */
    @Native("c++", "#this->cleanup()")
    public def cleanup():void { }
}
// vim: shiftwidth=4:tabstop=4:expandtab
