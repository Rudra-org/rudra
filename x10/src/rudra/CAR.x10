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
import rudra.util.Monitor;
import rudra.util.Unit;

import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;
import x10.util.Team;
import x10.io.Unserializable;

/** Simplified continuous allreduce implementation, does 
    not implement atLeastR feature.

    CRAB: implement allreduce with a reduce and bcast.

    Now reconciliation is done with two threads. The first thread
    does the allreduce or if CRAB, the reduce.  The second does the 
    bcast (if CRAB) and is responsible for updating weights as well.
    This permits the reduce or allreduce thread to operate continuously
    without stopping to bcast or update. This reduces the time in the 
    collective operation, allowing for more frequent sweeps.

    @author vj
 **/
public class CAR(config:RudraConfig, learnerGroup:PlaceGroup, CRAB:Boolean,
                 confName:String, noTest:Boolean,
                 weightsFile:String, meanFile:String, 
                 solverType:String, seed:Int, mom:Float,
                 adarho:Float, adaepsilon:Float,
                 spread:UInt, H:Float, S:UInt, 
                 ll:Int, lr:Int, lt:Int, ln:Int)   {
    val logger = new Logger(lr);
    static class State(reconcilerNL:NativeLearner, logger:Logger) implements Unserializable { 
        val monitor = new Monitor();
        var sizeMB:UInt = 0un; // #MB processed since last pickup
        var timeStamp:UInt = 0un; 
        val updateTimer = new Timer("Weight update times:");
        val loadTimer = new Timer("Weight load times:");
        def acceptNWGradient(rg:TimedGradient) {
            updateTimer.tic();
            monitor.atomicBlock(()=> {
                    timeStamp=rg.timeStamp;
                    val multiplier = 1.0f / rg.loadSize();
                    reconcilerNL.acceptGradients(rg.grad, multiplier);
                    sizeMB += rg.loadSize();
                    Unit()
                });
            updateTimer.toc();
            if (here.id==0)
                logger.info(()=>"Reconciler:<- Network, weights updated with " + rg + "(" 
                            + updateTimer.lastDurationMillis()+ " ms)"); 
            rg.setLoadSize(0un);
        }
        def fillInWeights(w:TimedWeight):Boolean {
            loadTimer.tic();
            val result = monitor.atomicBlock(()=> {
                    val newWeights = w.timeStamp < timeStamp;
                    if (newWeights) {
                        reconcilerNL.serializeWeights(w.weight);
                        w.setLoadSize(sizeMB);
                        w.timeStamp=timeStamp;
                        sizeMB=0un;
                    }
                    newWeights
                });
            loadTimer.toc();
            return result;
        }
    } // State


    static class Counts implements Unserializable { 
        val monitor = new Monitor();
        var index:Int=0n;
        var count:UInt=0un;
        def inc(i:Int, c:UInt):void {
            monitor.atomicBlock(()=> {
                    index += i;
                    count += c;
                    Unit()
                });
        }
        def count():UInt = monitor.atomicBlock(()=>count);
        def countFor(i:Int):UInt = monitor.on(()=> index >= i, ()=>count);
    } // Counts


    def run() {
        // TODO change getNetworkSize etc to be statics.
        val team = new Team(learnerGroup);
        val bcastTeam = new Team(learnerGroup);

        logger.info(()=>"CAR: Starting Main finish.");

        finish for (p in learnerGroup) at(p) async { // this is meant to leak in!!
                logger.info(()=>"CAR: In main async.");
            val done = new AtomicBoolean(false);
            Learner.initNativeLearnerStatics(config, confName, meanFile, seed, mom, 
                                             adarho, adaepsilon, ln);
            logger.info(()=>"CAR: Initialized native learner statics.");
            val nl = Learner.makeNativeLearner(config, weightsFile, solverType);
            logger.info(()=>"CAR: Made nl, native learner.");
            val networkSize = nl.getNetworkSize();
            val size = networkSize+1;
            val numEpochs = config.numEpochs;
            val numTrainSamples = config.numTrainSamples;
            val mbPerEpoch = config.mbPerEpoch();
            val maxMB = config.maxMB();

            val learner = new Learner(config, confName, spread,
                                         nl, team, new Logger(ll), lt, solverType);
            logger.info(()=>"CAR: Made learner, native learner.");
            val nlReconciler = Learner.makeNativeLearner(config, weightsFile, solverType);
            val state = new State(nlReconciler, logger);
            val counts = new Counts();
            if (weightsFile == null || weightsFile.equals("")) {
                logger.info(()=> "Reading init weights.");
                val initW = learner.initWeights();
                nlReconciler.deserializeWeights(initW);
            }
           val fromLearner = SwapBuffer.make[TimedGradient](true, new TimedGradient(size));
           val toUpdater = SwapBuffer.make[TimedGradient](false, new TimedGradient(size)); // blocking
           val timeStamp = new AtomicInteger(0n);

           if (here.id == 0) 
               logger.emit("CAR: The table is set. Training with "
                           + learnerGroup.size + " learners over "
                           + numTrainSamples + " samples, "
                           + numEpochs + " epochs, "
                           + mbPerEpoch + " minibatches per epoch = "
                           + maxMB + " minibatches.");
           
           async { // reduces continuously, place0 forwards reduced value to receiver
                logger.info(()=>"CAR.Reducer: started.");
                val zero  = new TimedGradient(size);
                var compG:TimedGradient  = new TimedGradient(size); 
                var dest:TimedGradient = new TimedGradient(size);
                val reduceTimer = new Timer("reduce Time:");
                val toUpdaterTimer = new Timer("to updater Time:");
                val bcastSyncTimer = new Timer("bcast Sync Time:");
                var myTotal:UInt = 0un; // total recd and communicated
                var index:Int=0n;
               L: while (true) { 
                    if ((! CRAB) && myTotal >= maxMB) break L;
                    index++;
                    val phi = myTotal, dest_=dest;
                    val loopStr="CAR.Reducer (phi="+myTotal+",index="+index +"):";;
                    compG.setLoadSize(0un);
                    val tmp = compG = fromLearner.get(compG);
                    val src = compG.loadSize() > 0un ? compG : zero;

                    logger.info(()=> loopStr+ "Entering reduce with " + src);
                    dest_.setLoadSize(0un);
                    reduceTimer.tic();
                    if (CRAB) {
                        bcastSyncTimer.tic();
                        if (counts.countFor(index-1n) >= maxMB) {
                            bcastSyncTimer.toc();
                            break L;
                        }
                        logger.info(()=> loopStr+ "Exiting bcast sync check.");
                        bcastSyncTimer.toc();
                        val delta = bcastSyncTimer.lastDurationMillis();
                        if (delta > 1) 
                            logger.info(()=>loopStr + "Syncing with bcast took " + delta + " ms");
                        team.reduce(Place(0), src.grad, 0, here.id==0?dest_.grad:src.grad, 
                                    0, src.grad.size, Team.ADD);
                    } else 
                        team.allreduce(src.grad, 0, dest_.grad, 0, src.grad.size, Team.ADD);
                    reduceTimer.toc();
                    if (here.id==0) {
                        logger.notify(()=> loopStr + "<- Network " + dest_ 
                                      + "(" + reduceTimer.lastDurationMillis()+" ms)");
                    }
                    if (((!CRAB) || here.id==0)) { 
                        val deltaLoad = dest_.loadSize();
                        if (CRAB || deltaLoad>0un) { // let it progress even with zero weight for CRAB
                            myTotal += deltaLoad;
                            // if CRAB, place 0 forwards locally thru toUpdater, and the bcast 
                            // in receiver will deliver for others. 
                            // If !CRAB, all forward locally
                            toUpdaterTimer.tic();
                            dest_.timeStamp=phi;
                            dest = toUpdater.put(dest_); // may block
                            toUpdaterTimer.toc();
                            val delta = toUpdaterTimer.lastDurationMillis();
                            if (delta > 1) 
                                logger.warning(()=>loopStr + "Stalled (" + delta + " ms)");
                        }
                    }
                }
                done.set(true);
                if (toUpdater.needsData()) toUpdater.put(dest); // unblock it if it is blocked there
                val index_=index, phi=myTotal;
                logger.info(()=>"CAR.Reducer: Exited main loop (phi=" + phi+",index=" + index_ + ")");
                logger.notify(()=> "" + reduceTimer);
           } // reducer
            async { // receiver. if CRAB, receives dest through bcast, else locally. Does updates.
                logger.info(()=>"CAR.Receiver: started.");
                var dest:TimedGradient  = new TimedGradient(size); 
                val grad  = new TimedGradient(size); // gradient for accumulation
                var myTimeStamp:UInt = 0un; // time measured in terms of MB processed
                var currentEpoch:UInt = 0un;
                val threshold:UInt = S / (config.mbSize*2un);
                val bcastTimer = new Timer("bcast Time:");
                val updateTimer = new Timer("update Time:");
                var index:Int=0n;
                while (!done.get()) { 
                    val phi=myTimeStamp, index_=index;
                    if ((!CRAB) || here.id==0) { 
                        dest = toUpdater.get(dest);  // blocking ...need to unblock on termination.
                        val dest_=dest;
                        if (here.id==0)
                        logger.info(()=>"CAR.Receiver: Received " + dest_ 
                                      + "locally (phi=" + phi + ",index=" + index_ + ")");
                    } else {
                        dest.timeStamp = phi;
                    }
                    val dest_=dest;
                    if (CRAB) {
                        bcastTimer.tic();
                        bcastTeam.bcast(Place(0), dest_.grad, 0, dest_.grad, 0, dest_.grad.size);
                        bcastTimer.toc();
                        index++;
                        counts.inc(1n, dest_.loadSize());
                        if (here.id==1) { 
                            logger.notify(()=>"CAR.Receiver: <- Network "  
                                          + dest_ + " at time=" + phi 
                                          + "(phi=" + phi + ",index="+index_ + " "  
                                          +  bcastTimer.lastDurationMillis()+" ms)");
                        }
                    } 
                    if (dest_.loadSize() + grad.loadSize() <= threshold) { // reduce
                        logger.info(()=> "CAR.Receiver: Reduced " + dest_ 
                                    + " into grad " + grad);
                        grad.addIn(dest_);
                    } else { // shift
                        dest_.addIn(grad);
                        grad.clear();
                        val deltaLoad= dest_.loadSize();
                        myTimeStamp += deltaLoad;
                        timeStamp.addAndGet(deltaLoad as Int);
                        dest_.timeStamp = myTimeStamp;
                        updateTimer.tic();
                        state.acceptNWGradient(dest_);
                        updateTimer.toc();
                        logger.info(()=> "CAR.Receiver: Shifted with " + dest_ 
                                    + "(phi=" + (phi+deltaLoad) + " " + 
                                    updateTimer.lastDurationMillis() + ")" );

                    }

                    // follow learning rate schedule given in config file
                    if ((myTimeStamp / mbPerEpoch) > currentEpoch) {
                        val newLearningRate = config.lrMult(++currentEpoch);
                        logger.notify(()=> "CAR.Receiver: updating learning rate to "+ newLearningRate);
                        state.reconcilerNL.setLearningRateMultiplier(newLearningRate);
                    }
                } // while
                val phi = myTimeStamp, index_=index;
                logger.notify(()=>"CAR.Receiver: Exited main loop (phi=" + phi + ",index=" + (index_+1)+")");
                if (CRAB) logger.notify(()=> "" + bcastTimer);
                logger.notify(()=> "" + updateTimer);
            } //reconciler
            logger.info(()=>"CAR.Learner: started. mbPerEpoch=" + mbPerEpoch);
            var compG:TimedGradient = new TimedGradient(size); 
            compG.timeStamp = UInt.MAX_VALUE;
            val testManager = here.id==0? learner.new TestManager(config, noTest, solverType) : null;
            if (testManager != null) testManager.initialize();
            val currentWeight = new TimedWeight(networkSize);
            val trainTimer = new Timer("Training time:");
            learner.epochStartTime = System.nanoTime();
            while (! done.get()) {
                learner.computeGradient(compG);
                compG = learner.deliverGradient(compG, fromLearner);
                if (state.fillInWeights(currentWeight)) { // may block
                    learner.acceptWeights(currentWeight);
                    if (testManager != null) testManager.touch();
                }
            } // while !done

            if (testManager != null) testManager.finalize();
            logger.info(()=>"CAR.Learner: Exited main loop.");
            logger.notify(()=> "" + learner.cgTimer);
            logger.notify(()=> "" + learner.weightTimer);
            logger.notify(()=> "" + state.updateTimer);
            } // async for finish
    }

}
// vim: shiftwidth=4:tabstop=4:expandtab
