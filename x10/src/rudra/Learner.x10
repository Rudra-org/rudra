/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import rudra.util.Logger;
import rudra.util.Timer;
import rudra.util.SwapBuffer;
import rudra.util.BlockingRXchgBuffer;

import x10.compiler.NonEscaping;
import x10.compiler.Pinned;
import x10.util.Team;
import x10.io.Unserializable;

@Pinned public class Learner(config:RudraConfig, confName: String, spread:UInt, 
                     nLearner: NativeLearner, 
                     team:Team, logger:Logger, lt:Int,
                     solverType:String) implements Unserializable {
    
    public static def initNativeLearnerStatics(config:RudraConfig, confName:String, meanFile:String,
                   seed:Int, mom:Float,
                   adaDeltaRho:Float, adaDeltaEpsilon:Float,
                   ln:Int) {
        NativeLearner.setLoggingLevel(ln);
        if (meanFile!=null) NativeLearner.setMeanFile(meanFile);
        NativeLearner.setAdaDeltaParams(adaDeltaRho, adaDeltaEpsilon, 
                                        Rudra.DEFAULT_ADADELTA_RHO, Rudra.DEFAULT_ADADELTA_EPSILON);
        NativeLearner.setSeed(here.id, seed, Rudra.DEFAULT_SEED);
        if (mom != Rudra.DEFAULT_MOM) NativeLearner.setMoM(mom);

        // WD created in common file system, only one place must do it.
        if (here.id==0) NativeLearner.setJobID(config.jobID);

        // now after the statics are set from command line, 
        // read in parameters from given cfg file.
        NativeLearner.initFromCFGFile(confName);
    }

    public static def makeNativeLearner(config:RudraConfig, weightsFile:String, solverType:String):NativeLearner {
        Console.OUT.println(here + " starting on host " + x10.xrx.Runtime.getName());
        val nl = new NativeLearner(here.id);
        nl.initAsLearner(config.trainData, config.trainLabels, config.mbSize, weightsFile, solverType);
        return nl; 
    } 

    static def getNetworkSize(nl:NativeLearner):UInt = nl.getNetworkSize() as UInt;

    val startTime = System.nanoTime();
    val id = here.id;
    var totalMBProcessed:UInt = 0un;
    var epoch:UInt = 0un;
    var timeStamp:UInt = 0un;
    val P = Place.numPlaces();
    val networkSize = getNetworkSize(nLearner);
    val size = networkSize+1;
    val numEpochs = config.numEpochs;
    val mbPerEpoch = config.mbPerEpoch();
    val maxMB = config.maxMB();
    val cgTimer = new Timer("Compute gradient time:");
    val weightTimer = new Timer("Weight update Time:");

    public def getNetworkSize():UInt = getNetworkSize(nLearner);

    public def acceptGradients(delta:Rail[Float], numMB:UInt):void {
        val multiplier = 1.0f / numMB;
        nLearner.acceptGradients(delta, multiplier);
    }

    public def serializeWeights(w:Rail[Float]): void{
        nLearner.serializeWeights(w);
    }

    public def deserializeWeights(w:Rail[Float]): void{
        nLearner.deserializeWeights(w);
    }

    public def trainMiniBatch():Float {
        val result = nLearner.trainMiniBatch();
        return result;
    }

    /** If cg already contains gradients, drop them if they are stale.
        Load, or accumulate gradients in cg after training a minibatch.
     */
    public def computeGradient(cg:TimedGradient):void {
        val ts = timeStamp;
        cgTimer.tic();
        // Train!
        val e = trainMiniBatch();
        // Get gradients from native learner, mixing them into old gradients, 
        // if they are not stale
        val stale = (cg.timeStamp+spread < ts);
        if (cg.loadSize() == 0un) {
            cg.timeStamp = timeStamp;
        } else {
            if (stale) {
                logger.warning(()=>"Learner: dropped old computed gradient " + cg);
                cg.timeStamp = timeStamp;
                cg.setLoadSize(0un);
            } else {
                // Take the min here because compG may have accumulated
                // gradients from past incarnations.
                if (ts != cg.timeStamp)
                    logger.info(()=> "Gradient "+cg+" will be mixed with gradient generated at " + ts);
                }
            }
            val cgsz = cg.loadSize();
            assert ((cgsz==0un && cg.timeStamp==ts)||(cgsz>0un && cg.timeStamp+spread>=ts))
                : "Learner: old computed gradient " + cg + " is stale at time " + ts + " and still alive.";
            //        logger.info(()=> "Learner: retrieving gradient");
        getGradients(cg.grad);    
        //        logger.info(()=>"Learner: produced " + cg);
        cgTimer.toc();
        logger.notify(()=>"Learner: train error=" + e
                      + " at time=" + ts + "(" + cgTimer.lastDurationMillis()+" ms)");
    }
    public def deliverGradient(cg:TimedGradient, 
                               fromLearner:SwapBuffer[TimedGradient]):TimedGradient {
        // Try to deliver gradients to reconciler.
        val tmp = fromLearner.put(cg);
        val sent = (tmp != cg);
        logger.info(()=>"Learner:->Reconciler " + (sent?"delivered ":"tried to deliver ") + cg);
        if (sent) { // successful delivery! compG now contains junk.
            tmp.setLoadSize(0un);
            tmp.timeStamp = timeStamp;
            return tmp;
        } else {
            if (cg.loadSize()>10un)
                logger.warning(()=>"Learner:*** Reconciler seems unresponsive, unable to deliver " + cg.loadSize() + " times.");
            return cg;
        }
    }
    /**
       Modify the updates rail in place (it may contain garbage), except for
       the last value which tracks the number of mini-batches whose gradients
       have been accumulated in this rail. If it is > EPS, then the native call
       must sum-accumulate the new gradient into the updates rail, and increment
       the last value.
     */
    public def getGradients(updates:Rail[Float]):void {
        if (updates(updates.size-1) > 0.0) {
            nLearner.accumulateGradients(updates);
        } else {
            nLearner.getGradients(updates);
        }
        // increase number of gradients received
        updates(updates.size-1) += 1.0f;
    }

    def acceptNWGradient(g:TimedGradient):void {
        val includeMB = g.loadSize();
        // have received a new incoming gradient from reconciler (guaranteed to have some gradients)
        logger.info(()=>"Learner:<-Reconciler " + g);
        assert includeMB > 0un: "Learner: gradient received from reconciler should not be empty.";
        assert g.timeStamp > timeStamp : "Learner: at " + timeStamp 
            + " received network input at older time " + g.timeStamp;
        timeStamp = g.timeStamp;
        acceptGradients(g.grad, includeMB);
        totalMBProcessed += includeMB;
        logger.info(()=>"Learner: processed network i/p " + g);
    }

    public def getTotalMBProcessed():UInt = totalMBProcessed;
    var epochStartTime:Long = 0;

    /**
     * The TestManager runs at Place 0 (alongside either a parameter server or a
     * learner) and sends weights to the Tester, which performs testing at
     * Place(P-1).
     */
    public class TestManager(config:RudraConfig, noTest:Boolean, solverType:String) {
        val toTester = new BlockingRXchgBuffer[TimedWeightWRuntime](new TimedWeightWRuntime(networkSize));
        var weights:TimedWeightWRuntime= new TimedWeightWRuntime(networkSize);
        var lastTested:UInt=0un;
        def initialize() {
            if (noTest) return;
            val testerPlace = Place.places()(Place.numPlaces()-1);
            async new Tester(config, testerPlace, confName, new Logger(lt), solverType).run(networkSize, toTester);
        }

        def touch() { touch(null); }

        def touch(tw:TimedWeight):void {
            if (noTest) return;
            // Called by place 0 learner or PS: Test for epoch transition.
            // Try to get a Tester to run with these weights
            val ts = tw==null? getTotalMBProcessed() : tw.timeStamp();
            val thisEpoch = ts/mbPerEpoch;
            if (thisEpoch <= epoch) return;
            val oldEpoch = epoch;
            val epochEndTime = System.nanoTime();
            val epochRuntime = epochEndTime-epochStartTime;
            val timeTaken = Timer.time(epochRuntime);
            //            logger.emit(()=>"Learner: Epoch "  + oldEpoch + " took " + timeTaken);
            epoch = thisEpoch;
            epochStartTime=epochEndTime;
            if (tw == null) serializeWeights(weights.weightRail());
            else  Rail.copy(tw.weightRail(), weights.weightRail());
            weights.setTimeStamp(oldEpoch);
            weights.setRuntime(epochRuntime/(1000*1000)); // in ms.
            val w = weights;
            logger.emit(()=>"Learner: Pinging tester with "  + w);
            weights = toTester.put(weights);
            if (weights != w) lastTested=oldEpoch;
            logger.emit(()=>"Learner: Tester "+(weights!=w?"accepted " : "did not accept ")+w);
        }

        def finalize() {
            if (!noTest) {
                if (lastTested < epoch) { // make sure u test the last weights
                    weights.timeStamp=epoch;
                    serializeWeights(weights.weight);
                    toTester.put(weights);
                }
                toTester.put(TimedWeightWRuntime.POISON);
            }
        }
    } // TestManager

    /** 
        Ensure that all learners start with the same initial weight. Should not
        be called if weightsFile was specified -- then we load weights from the 
        weightsFile in any case.
     */
    public def initWeightsIfNeeded(weightsFile:String):Rail[Float] {
        if (weightsFile == null || weightsFile.equals("")) {
            logger.info(()=>"Learner: starting initWeights.");
            return initWeights();
        }
        return null;
    }
    public def initWeights():Rail[Float] {
        // learner 0 broadcast weights, to make sure that we start from the same 
        val ns = networkSize as Long;
        val initW:Rail[Float] = new Rail[Float](ns);
        if (here.id == 0)serializeWeights(initW); // place zero serialize weights
        try {
            logger.info(()=>"Learner:entering initWeight bcast:" + TimedWeight.calcHash(initW));
            team.bcast(Place(0), initW, 0l, initW, 0l, ns);
            logger.info(()=>"Learner:exitinginitWeight bcast:" + TimedWeight.calcHash(initW));
        }catch (z: Error) {
            logger.error(()=>"Learner.initWeights: error in bcast! " + z);
            z.printStackTrace();
            throw new Error("Bailing wire and chewing gum. 1");
        } catch (z: CheckedThrowable) {
            logger.error(()=>"Learner.initWeights: error in bcast! " + z);
            z.printStackTrace();
            throw new Error("Bailing wire and chewing gum");
        }
        logger.info(()=>"Learner:exited initWeight bcast.");
        if (here.id != 0) deserializeWeights(initW);
        return initW;
    }
    public def acceptWeights(cw:TimedWeightI) {
        acceptWeights(cw, System.nanoTime());
    }
    public def acceptWeights(cw:TimedWeightI, startTime:Long) {
        assert (cw.timeStamp() > timeStamp): "Learner:acceptWeights called with older "
            + cw + " (time " + timeStamp+")";
        logger.info(()=>"Learner: accepting weights " + cw);
        val includeMB = cw.loadSize();
        timeStamp = cw.timeStamp();
        totalMBProcessed += includeMB;
        deserializeWeights(cw.weightRail());
        weightTimer.addDuration(System.nanoTime()-startTime);
        logger.info(()=>"Learner: accepted weights " + cw);
    }
}
// vim: shiftwidth=4:tabstop=4:expandtab
