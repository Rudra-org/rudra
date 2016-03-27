/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.compiler.Uncounted;
import x10.util.Team;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

import rudra.util.Logger;
import rudra.util.Timer;
import rudra.util.Monitor;
import rudra.util.SwapBuffer;
import rudra.util.XchgBuffer;
import rudra.util.BBuffer;
import rudra.util.Unit;
import x10.io.Unserializable;
/*
  The Downpour algorithm -- each learner periodicallys ends its gradients 
  to the Parameter server, and requests current weights from it.

  @author vj
 */
public class SendReceive(config:RudraConfig,
                         learnerGroup:PlaceGroup, numXfers:UInt,
                         noTest:Boolean, confName:String, 
                         weightsFile:String, meanFile:String, 
                         solverType:String, seed:Int, mom:Float,
                         adarho:Float, adaepsilon:Float,
                           spread:UInt, 
                           ll:Int, lt:Int, ln:Int)  {

    val logger = new Logger(ll);
    static public class State(toLearner:XchgBuffer[GlobalTimedWeight], 
                              PS:GlobalRef[ParameterServer],
                              done: AtomicBoolean, logger:Logger, 
                              networkSize:Long,
                              maxMB:UInt) {
        var w:GlobalTimedWeight = new GlobalTimedWeight(networkSize);
        var phase:UInt=0un;
        var myGlobalRef:GlobalRef[State];
        val busy = new AtomicBoolean(false);
        def initialize() {
            myGlobalRef = GlobalRef[State](this);
        }
        public def sendRequest() {
            if (! busy.get()) {
                busy.set(true);
                val phi = phase;
                logger.info(()=>"SR.receiver: Sending weight request in phase " + phi);
                val ww= w, g = myGlobalRef;
                at(PS) @Uncounted async PS().sendWeights(ww, g);
            }
        }
        public def acceptResult(ts:UInt) {
            phase = ts;
            w.setTimeStamp(ts);
            toLearner.xchg(w);
            val pphase=phase;
            logger.info(()=>"SR.receiver: Received weights " + w);
            w = toLearner.xchg(w); 
            if (phase >= maxMB) {
                logger.info(()=>"SR.receiver: Terminating, maxMB reached.");
                done.set(true);
            }
            busy.set(false);
        } 
    }

    class ParameterServer extends Learner implements Unserializable {
        public def this(config:RudraConfig, confName:String,
                        spread:UInt, seed:Int,
                        team:Team, logger:Logger, lt:Int, solverType:String, nLearner:NativeLearner) {
            super(config, confName, spread, nLearner, team, logger, lt, solverType);
        }

        var testManager:TestManager = null;

        // controls the number of transfers that are supported simultaneously
        // "filled", with nulls.
        val railBuffer = new BBuffer[Rail[Float]](numXfers as Int, null, numXfers as Int); 
        // "empty" initially
        val gradBuffer = new BBuffer[Rail[Float]](numXfers as Int, null, 0n); 
        //        val weightRequestBuffer = new BBuffer[GlobalTimedWeight](numXFers as Int, null, numXfers as Int); // filled with nulls.
        val xferTimer = new Timer("Gradient xfer time:");
        val timeStamp = new AtomicInteger(0n);

        /** Accept a request from a learner to receive gradients. 
            Transfer the gradient, and queue it up for further 
            processing. Note: the thread running accept is an "X10RT" thread,
            running the at executed by the remote learner. On return
            from this method the remote learner knows that the data in its
            GTG has been transferred, and it can reuse it.
         */
        def accept(g:GlobalTimedGradient) {
            val ts = timeStamp.get() as UInt;
            logger.info(()=> "PS: Receiving " + g + " at ="+ ts);
            if (ts >= maxMB) { // we have terminated!
                logger.warning("PS has terminated, dropping incoming " + g);
                return;
            }
            if (g.timeStamp + spread < ts) {
                logger.warning("PS: stale gradient " + g + " dropped in phase " + ts);
                return;
            }
            val rail_ = railBuffer.get(); // get the rail to work with
            val rail = rail_==null? new Rail[Float](size) : rail_;
                 xferTimer.tic();
            finish Rail.asyncCopy(g.grad, 0, rail, 0, rail.size);
                 xferTimer.toc();
                 logger.info(()=> "PS: acquired buffer data for " + g + " in " + 
                             xferTimer.lastDurationMillis() + " ms");
            gradBuffer.put(rail);
        } // accept

        val weightMonitor = new Monitor();
        val myWeights = new TimedWeight(networkSize as Long);
        val sendTimer = new Timer("Send weights time:");

        def sendWeights(w:GlobalTimedWeight, g:GlobalRef[State]):void {
            logger.info(()=>"PS.sendWeights: Received sendWeight request from " + w);
            weightMonitor.atomicBlock(()=> {
                    serializeWeights(myWeights.weight);
                    myWeights.setTimeStamp(totalMBProcessed);
                    Unit()
                });
            logger.info(()=>"PS.sendWeights: Serialized weights into  " + myWeights);
            sendTimer.tic();
            val ts =myWeights.timeStamp();
            Rail.uncountedCopy(myWeights.weight, 0, w.weight, 0, networkSize as Long, 
                               ()=> {
                                   val gtw = g();
                                   gtw.acceptResult(ts);
                               });
            sendTimer.toc();
        }

        def run() {
            logger.info(()=>"PS: Starting initialize");
            testManager = (this as Learner).new TestManager(config, noTest, solverType);
            testManager.initialize();
            epochStartTime  = System.nanoTime();
            initWeightsIfNeeded(weightsFile);

            logger.info(()=>"PS: At rock and roll barrier");
            team.barrier(); // ready to rock and roll
            while (totalMBProcessed < maxMB) {
                val rail = gradBuffer.get();
                logger.info(()=> "PS: in monitor, updating weights with ");
                weightMonitor.atomicBlock(()=>{
                        acceptGradients(rail, 1un);
                        totalMBProcessed++;                        
                        timeStamp.incrementAndGet();
                        testManager.touch(); // may need to serialize weights
                        Unit()
                    });
                railBuffer.put(rail); // now return it
            } // while
            logger.notify("PS: Shutting down.");
            testManager.finalize();
            logger.info(()=> "PS: Finished. TestManager finalized.");
            logger.notify(()=> ""+sendTimer);
            logger.notify(()=>""+xferTimer);
        } // initialize
    } // ParameterServer
    def run() {
        val team = new Team(learnerGroup);

        Learner.initNativeLearnerStatics(config, confName, meanFile, seed, mom, 
                                         adarho, adaepsilon, ln);
        val nl = Learner.makeNativeLearner(config, weightsFile, solverType);

        val networkSize = nl.getNetworkSize();
        val size = networkSize+1;
        val numEpochs = config.numEpochs;
        val numTrainSamples = config.numTrainSamples;
        val mbPerEpoch = config.mbPerEpoch();
        val maxMB = config.maxMB();

        val PS__ = new GlobalRef[ParameterServer](
                                                  new ParameterServer(config, confName,
                                                spread, seed, team, logger, 
                                                lt, solverType, nl)); 
        logger.emit("SR: The table is set. Training with "
                    + learnerGroup.size + " learners over "
                    + numTrainSamples + " samples, "
                    + numEpochs + " epochs, "
                    + mbPerEpoch + " minibatches per epoch = "
                    + maxMB + " minibatches.");


        logger.info(()=>"SR: Starting Main finish.");
        finish {
            async PS__().run();
            logger.info(()=>"SR: Starting place loop");
            for (p in learnerGroup) 
                if (p.id !=0) at(p) async { 
                        Learner.initNativeLearnerStatics(config, confName, meanFile,
                                                         seed, mom, 
                                                         adarho, adaepsilon, ln);
                        logger.info(()=>"SR: Starting main at " + here);
                        val nLearner = Learner.makeNativeLearner(config, weightsFile, solverType);
                        val done = new AtomicBoolean(false);
                        val fromLearner = SwapBuffer.make[GlobalTimedGradient](false, 
                                             new GlobalTimedGradient(size)); // blocking
                        val toLearner = new XchgBuffer[GlobalTimedWeight](new GlobalTimedWeight(networkSize)); 
                        val learner = new Learner(config, confName, spread,
                                                  nLearner, team, logger, lt, solverType);
                        learner.epochStartTime= System.nanoTime();
                        learner.initWeightsIfNeeded(weightsFile);
                        logger.info(()=>"SR.learner: ready to rock and roll.");
                        team.barrier(); // ready to rock and roll

                        async { // sender
                            var mycg:GlobalTimedGradient = new GlobalTimedGradient(size);
                            logger.info(()=>"SR.sender: Entering main loop");
                            // Learner will block if gradients have not been picked up by PS.
                            while (! done.get()) {
                                logger.info(()=>"SR.sender: Waiting for input from learner ");
                                val m = mycg = fromLearner.get(mycg); // blocking
                                logger.info(()=>"SR.sender: Sending " + m);
                                at (PS__) PS__().accept(m);
                                logger.info(()=>"SR.sender: Sent " + m);
                                mycg.setLoadSize(0un);
                            }
                        } // sender

                        // main Learner compute loop
                        val scratchTG = new TimedGradient(size);
                        var compG:GlobalTimedGradient = new GlobalTimedGradient(size); 
                        val learnerWaitTimer = new Timer("SR.learner wait time:");
                        var cw:GlobalTimedWeight = new GlobalTimedWeight(learner.networkSize);
                        val state = new State(toLearner, PS__, done, logger, 
                                              networkSize, maxMB);
                        state.initialize();

                        while (!done.get()) {
                            scratchTG.grad = compG.grad();
                            learner.computeGradient(scratchTG);
                            compG.timeStamp = scratchTG.timeStamp;
                            //                            compG.setLoadSize(1un);
                            learnerWaitTimer.tic();
                            compG = fromLearner.put(compG);
                            learnerWaitTimer.toc();
                            val stallDuration = learnerWaitTimer.lastDurationMillis();
                            if ( stallDuration > 1) 
                                logger.warning(()=>"SR.learner: stalled " 
                                               + stallDuration + " ms");
                            //                            compG.setLoadSize(0un);
                            state.sendRequest();
                            cw.setLoadSize(0un);
                            val tmp = cw = toLearner.xchg(cw); // non-blocking
                            if (cw.timeStamp() > learner.timeStamp) {
                                logger.info(()=>"SR.learner: received new weights" + tmp);
                                learner.acceptWeights(cw);
                            }
                        }
                        logger.info(()=>"SR.learner: terminated.");
                        logger.notify(()=> "" + learnerWaitTimer);
                        if (here.id==1) {
                            logger.notify(()=> "" + learner.cgTimer);
                            logger.notify(()=> "" + learner.weightTimer);
                        }
                    } // learner
        } // finish
    } //run

}
// vim: shiftwidth=4:tabstop=4:expandtab
