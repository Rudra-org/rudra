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
        val testManager = here.id==0? (this as Learner).new TestManager(config, noTest, solverType) : null;
        if (here.id==0) testManager.initialize();
        val dest = new TimedGradient(size);
        epochStartTime= System.nanoTime();
        initWeightsIfNeeded(weightsFile); 
        val loggerRec = new Logger(lr);
        var currentEpoch:UInt = 0un;
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
            weightTimer.toc();
            // follow learning rate schedule given in config file
            if ((totalMBProcessed / mbPerEpoch) > currentEpoch) {
                val newLearningRate = config.lrMult(++currentEpoch);
                loggerRec.notify(()=> "Reconciler: updating learning rate to "+ newLearningRate);
                nLearner.setLearningRateMultiplier(newLearningRate);
            }
            if (testManager != null) testManager.touch();
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
