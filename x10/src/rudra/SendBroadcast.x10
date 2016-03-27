/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.util.Team;
import x10.util.Random;
import x10.util.concurrent.AtomicBoolean;
import x10.util.concurrent.AtomicInteger;

import rudra.util.Logger;
import rudra.util.Timer;
import rudra.util.Monitor;
import rudra.util.SwapBuffer;
import rudra.util.XchgBuffer;
import rudra.util.BlockingRXchgBuffer;
import rudra.util.BBuffer;
import rudra.util.Unit;

/*
  The goal of this algorithm is to update weights in small steps 
  (one mini-batch at a time), while minimizing spread (difference 
  in ages of weights used by different learners at the same time).

  Like dist-belief, this algorithm has learners 
  directly communicate gradients to the parameter server (PS). The
  PS applies weights as soon as they are received to generate a new
  weight. The new weight is broadcast to all learners. 

  Each place other than Place 0 has three user threads: learner, 
  sender, receiver.

  The learner thread runs MB against the current weight, communicates 
  them to the sender thread which sends them on to Place zero. 
  The receiver thread sits in a team broadcast waiting for weights from
  place zero. It keeps only one set of weights, updating them 
  if a new set of weights arrive. After each MB, the learner 
  receives the current weights from the receiver thread. 
  
  At place zero (the Parameter Server place), incoming at's fetch space
  from a local buffer, transfer incoming gradient to this buffer and queue
  it up to the main thread for processing. The main thread accepts gradients,
  updates weights in the NN (if SUnit payloads have been processed), 
  serializes weights into a buffer, sends them to the bcast thread 
 (once beatCountUnits have been processed), and also touches 
  the TestManager to handle test error generation and checkpointing.

  @author vj
 */
public class SendBroadcast(config:RudraConfig,
                           learnerGroup:PlaceGroup, hardSync:Boolean,
                           confName:String, noTest:Boolean,
                           weightsFile:String, meanFile:String, 
                           solverType:String, seed:Int, mom:Float,
                           adarho:Float, adaepsilon:Float, 
                           spread:UInt, H:Float, S:UInt, 
                           ll:Int, lt:Int, ln:Int)  {
    val logger = new Logger(ll);

    class ParameterServer(beatCount:UInt, numXfers:UInt) extends Learner {
        public def this(config:RudraConfig, beatCount:UInt, numXfers:UInt,
                        confName:String, spread:UInt, seed:Int,
                        team:Team, logger:Logger, lt:Int, solverType:String, nLearner:NativeLearner) {
            super(config, confName, spread, nLearner, team, logger, lt, solverType);
            property(beatCount, numXfers);
        }

        // controls the number of transfers that are supported simultaneously
        // "filled", with nulls.
        // railBuffer: contains rails to use to process incoming messages
        val railBuffer = new BBuffer[Rail[Float]](numXfers as Int, null, numXfers as Int); 
        val xferTimer = new Timer("Gradient xfer time:");
        val timeStamp = new AtomicInteger(0n);

        // used to communicate filled grad buffer to main thread, empty initially
        val gradBuffer = new BBuffer[Rail[Float]](numXfers as Int, null, 0n); 

        /** Accept a request from a learner to receive gradients. 
            Transfer the gradient, and queue it up for further 
            processing. Note: the thread running accept is an "X10RT" thread,
            running the at executed by the remote learner. On return
            from this method the remote learner knows that the data in its
            GTG has been transferred, and it can reuse it.
         */
        def accept(g:GlobalTimedGradient) {
            val ts = timeStamp.get() as UInt;
            logger.info(()=> "PS.accept: Receiving " + g + " at time ="+ ts);
            if (ts >= maxMB) { // we have terminated!
                logger.warning("PS has terminated, dropping incoming " + g);
                return;
            }
            if (g.timeStamp + spread < ts) {
                logger.warning("PS.accept: stale gradient " + g + " dropped in phase " + ts);
                return;
            }
            xferTimer.tic();
            logger.info(()=>"PS.accept: acquiring rail for " + g);
            val rail_ = railBuffer.get(); // get the rail to work with
            val rail = rail_==null? new Rail[Float](size) : rail_;
            logger.info(()=>"PS.accept: acquired rail for " + g);
            finish Rail.asyncCopy(g.grad, 0, rail, 0, rail.size);
            gradBuffer.put(rail);
            xferTimer.toc();
            logger.info(()=> "PS.accept: acquired buffer data for " + g + " in " + 
                        xferTimer.lastDurationMillis() + " ms");

        } // accept
        def run() {
            logger.info(()=>"PS: Starting initialize");
            val testManager = noTest ? null : (this as Learner).new TestManager(config, noTest, solverType);
            if (testManager!= null) testManager.initialize();
            epochStartTime  = System.nanoTime();
            initWeightsIfNeeded(weightsFile);

            logger.info(()=>"PS: At rock and roll barrier");
            team.barrier(); // ready to rock and roll

            // used to send weights to learners and tester
            val toLearners = new BlockingRXchgBuffer[TimedWeight](new TimedWeight(networkSize)); 
            val done = new AtomicBoolean(false);

            // Need a separate thread to bcast, otherwise the main thread
            // is slowed down, and lots of messages get backed up, increasing
            // staleness dramatically, and leading to non-convergence

            // broadcast thread continuously xmits latest weight received from 
            // main thread. We can throttle it down if we need to.

            async { // bcast thread
                var weights:TimedWeight  = new TimedWeight(networkSize);
                val sizeRail = new Rail[UInt](1,0un);
                val bcastTimer = new Timer("Weight Broadcast time:");
                while (! done.get()) {
                    val old = weights;
                    logger.info(()=> "PS.bcast: waiting for input at " +  old.timeStamp()); 
                    val wt = weights = toLearners.get(weights);
                    logger.info(()=> "PS.bcast: got " + wt + " for " + old); 
                    if (wt.timeStamp() > old.timeStamp()) { // bcast
                        logger.info(()=> "PS.bcast: starting twin bcast of " + wt);
                        bcastTimer.tic();
                        val w = wt.weightRail();
                        sizeRail(0)= wt.timeStamp();
                        team.bcast(Place(0), w, 0, w, 0, w.size);
                        team.bcast(Place(0), sizeRail, 0, sizeRail, 0, sizeRail.size);
                        bcastTimer.toc();
                        logger.info(()=> "PS.bcast: bcast took " 
                                    + bcastTimer.lastDurationMillis()  + " ms");
                    }
                } // while
                logger.notify(()=> "" + bcastTimer);
            } // broadcast thread
            var weights:TimedWeight = new TimedWeight(networkSize);
            val updateTimer = new Timer("Weight update time:");
            var countToReduce:UInt = 0un;
            var countToBcast:UInt = 0un;
            var weightAge:UInt = 0un;
            var lastWeightSent:UInt = 0un;
            val rand = new Random();
            val SUnits = S / config.mbSize;
            val beatCountUnits = beatCount / config.mbSize;
            var gradient: Rail[Float] = SUnits > 1un? new Rail[Float](size) : null;
            while (totalMBProcessed < maxMB) {
                logger.info(()=> totalMBProcessed + " ** " + maxMB);
                logger.info(()=> "PS.main: Waiting for gradBuffer");
                val rail = gradBuffer.get(); // blocking
                updateTimer.tic();
                if (SUnits > 1un) {
                    for (i in 0..(size-1)) gradient(i) += rail(i);
                    countToReduce++;
                    if (countToReduce < SUnits && rand.nextFloat() <= H) {
                        railBuffer.put(rail); 
                        val cr = countToReduce;
                        logger.info(()=> "PS.main: continuing countToReduce=" + cr);
                        continue; // keep accumulating
                    }
                    // fall through
                } else {
                    gradient = rail;
                    countToReduce = 1un;
                }
                // Reduce, i.e. generate new weight from exist weight and gradient
                val cr= countToReduce, cb = countToBcast;
                logger.info(()=> "PS.main: reducing countToReduce=" + cr
                            + " countToBcast="  + cb);
                acceptGradients(gradient, countToReduce);
                railBuffer.put(rail);
                if (gradient != rail) gradient.clear();
                totalMBProcessed += countToReduce;
                countToBcast += countToReduce;
                timeStamp.addAndGet(countToReduce as Int);
                countToReduce = 0un;
                weightAge++;
                if (countToBcast >= beatCountUnits) {
                    val cb1 = countToBcast, wa= weightAge;
                    countToBcast = 0un;
                    serializeWeights(weights.weightRail());
                    weights.setTimeStamp(totalMBProcessed);
                    lastWeightSent = totalMBProcessed;
                    val w = weights;
                    logger.info(()=> "PS.main: bcasting, countToBcast="+ cb1 
                                + " weightAge=" + wa + " wt=" + w);
                    logger.info(()=> "PS: 1 pinging test Manager " + w);
                    if (testManager!=null) testManager.touch(w);                     
                    weights = toLearners.put(weights); // bcast to learners
                } else {
                    logger.info(()=> "PS.main: 2 pinging test Manager");
                    if (testManager!=null) testManager.touch();                     
                }
               updateTimer.toc();
            } // while
            logger.notify("PS.main: Shutting down.");
            if (lastWeightSent < totalMBProcessed) {
                // not really needed, we are going to ignore any incoming gradients
                serializeWeights(weights.weightRail()); 
                weights.setTimeStamp(totalMBProcessed);
                weights = toLearners.put(weights);
            }
            done.set(true);
            logger.info(()=> "PS.main: Finished.");
            if (testManager!=null) {
                testManager.finalize();
                logger.info(()=> "TestManager finalized.");
            }
            logger.notify(()=>""+xferTimer);
            logger.notify(()=>""+updateTimer);
        } // initialize
    } // ParameterServer
    def run(beatCount:UInt, numXfers:UInt) {
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
                                      new ParameterServer(config, beatCount, numXfers,
                                                confName,
                                                spread, seed, team, logger, 
                                                lt, solverType, nl)); 
        logger.emit("SB: The table is set. Training with "
                    + learnerGroup.size + " learners over "
                    + numTrainSamples + " samples, "
                    + numEpochs + " epochs, "
                    + mbPerEpoch + " minibatches per epoch = "
                    + maxMB + " minibatches.");


        logger.info(()=>"SB: Starting Main finish.");
        finish {
            val root = here;
            async PS__().run();
            logger.info(()=>"SB: Starting place loop");
            for (p in learnerGroup)
                if (p.id !=0) at(p) async { 
                        Learner.initNativeLearnerStatics(config, confName, meanFile,
                                                         seed, mom, 
                                                         adarho, adaepsilon, ln);
                        logger.info(()=>"SB: Starting main at " + here);
                        val nLearner = Learner.makeNativeLearner(config, weightsFile, solverType);
                        val done = new AtomicBoolean(false);
                        val fromLearner = SwapBuffer.make[GlobalTimedGradient](false, 
                                             new GlobalTimedGradient(size)); // blocking
                        // if hard, then learner must block until new weights are avail
                        val toLearner = hardSync ? SwapBuffer.make[TimedWeight](false, 
                                          new TimedWeight(networkSize)) // blocking
                            : new XchgBuffer[TimedWeight](new TimedWeight(networkSize)); 
                        val learner = new Learner(config, confName, spread,
                                                  nLearner, team, logger, lt, solverType);
                        learner.epochStartTime= System.nanoTime();
                        learner.initWeightsIfNeeded(weightsFile);
                        logger.info(()=>"SB.learner: ready to rock and roll.");
                        team.barrier(); // ready to rock and roll

                        async { // sender
                            var mycg:GlobalTimedGradient = new GlobalTimedGradient(size);
                            logger.info(()=>"SB.sender: Entering main loop");
                            // Learner will block if gradients have not been picked up by PS.
                            while (! done.get()) {
                                logger.info(()=>"SB.sender: Waiting for input from learner ");
                                val m = mycg = fromLearner.get(mycg); // blocking
                                logger.info(()=>"SB.sender: Sending " + m);
                                at (PS__) PS__().accept(m);
                                logger.info(()=>"SB.sender: Sent " + m);
                                mycg.setLoadSize(0un);
                            }
                            logger.info(()=>"SB.sender: terminated.");
                        } // sender

                        async { // receiver
                            // will run continuously in a loop waiting for broadcasts.
                            var w:TimedWeight = new TimedWeight(networkSize);
                            var phase:UInt=0un;
                            val sizeRail = new Rail[UInt](1,0un);
                            val bcastTimer = new Timer("Receiver bcast times:");
                            logger.info(()=>"SB.receiver: Entering main loop");
                            while (phase < maxMB) {
                                val phi = phase;
                                logger.info(()=>"SB.receiver: Entering bcast in phase " + phi);
                                bcastTimer.tic();
                                team.bcast(root, w.weight, 0, w.weight, 0, w.weight.size);
                                team.bcast(root, sizeRail, 0, sizeRail, 0, 2);
                                bcastTimer.toc();
                                logger.info(()=>"SB.receiver: Left bcast in phase " + phi);
                                w.setLoadSize(sizeRail(0)-phi);
                                w.timeStamp = phase = sizeRail(0);
                                if (here.id==1) 
                                    logger.notify("SB.receiver: broadcast " + phi
                                                  + "(jumped to " + w.timeStamp + ") took " + 
                                                  bcastTimer.lastDurationMillis() + " ms");
                                // Exchange with buffer, so buffer always has latest copy
                                // of weights to be picked up by the learner.
                                w = toLearner.put(w); 
                            }
                            done.set(true);
                            logger.info(()=>"SB.receiver: terminated.");
                            if (here.id==1) logger.notify(() => "" + bcastTimer);
                        } // receiver

                        // main Learner compute loop
                        val scratchTG = new TimedGradient(size);
                        var compG:GlobalTimedGradient = new GlobalTimedGradient(size); 
                        val learnerWaitTimer = new Timer("SB.learner wait time:");
                        var cw:TimedWeight = new TimedWeight(learner.networkSize);

                        while (!done.get()) {
                            scratchTG.grad = compG.grad();
                            learner.computeGradient(scratchTG);
                            compG.timeStamp = scratchTG.timeStamp;
                            //                            compG.setLoadSize(1un);
                            learnerWaitTimer.tic();
                            val cg=compG;
                            logger.info(()=>"SB.learner: sending " + cg + " to SB.sender");
                            compG = fromLearner.put(compG);
                            learnerWaitTimer.toc();
                            val stallDuration = learnerWaitTimer.lastDurationMillis();
                            if ( stallDuration > 1) 
                                logger.warning(()=>"SB.learner: stalled " 
                                               + stallDuration + " ms");
                            //                            compG.setLoadSize(0un);
                            val tmp = cw = toLearner.get(cw); // non-blocking, unless -hard
                            logger.info(()=>"SB.learner: received " + tmp + " from receiver");
                            if (cw.timeStamp() > learner.timeStamp) {
                                logger.info(()=>"SB.learner: received new weights" + tmp);
                                learner.acceptWeights(cw);
                            }
                        }
                        logger.info(()=>"SB.learner: terminated.");
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
