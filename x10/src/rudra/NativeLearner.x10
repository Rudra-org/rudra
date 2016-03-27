/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.compiler.Native;
import x10.compiler.NativeCPPInclude;
import x10.compiler.NativeRep;

/**
 * Container class for a native learner.
 */
@NativeCPPInclude("NativeLearnerWrapper.h")
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

    @Native("c++", "#this->initAsTester(#placeId, #solverType->c_str())")
    public def initAsTester(placeId:Long, solverType:String):void { }
        
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
            
    @Native("c++", "#this->testOneEpochSC(#weights->raw, #numTesters, #myIndex)")
        public def testOneEpochSC(weights:Rail[Float], numTesters:Long, myIndex:Long):Float {
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
