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
import rudra.util.MergingMonitor;

import x10.util.concurrent.AtomicBoolean;
import x10.util.Team;
import x10.io.Unserializable;
import x10.compiler.Pinned;

@Pinned public class ApplyLearner extends Learner implements Unserializable {
    val mm:MergingMonitor;
    public def this(confName:String, mbPerEpoch:UInt, spread:UInt, 
                    done:AtomicBoolean, mm: MergingMonitor,
                    team:Team, logger:Logger, lt:Int, nLearner:NativeLearner) {
        super(confName, mbPerEpoch, spread, done, nLearner, team, logger, lt);
        this.mm=mm;
    }

    val trainTimer = new Timer("Training Time:");
    val weightTimer = new Timer("Weight update Time:");
    def run(fromLearner:SwapBuffer[TimedGradient], reconciler:ApplyReconciler) {
        logger.info(()=>"Learner: started. mbPerEpoch=" + mbPerEpoch);
        var compG:TimedGradient = new TimedGradient(size); 
        compG.timeStamp = UInt.MAX_VALUE;
        val testManager = here.id==0? this.new TestManager() : null;
        if (testManager != null) testManager.initialize();
        val currentWeight = new TimedWeight(networkSize);
        initWeights();
        epochStartTime = System.nanoTime();
        while (! done.get()) {
            trainTimer.tic();
            computeGradient(compG);
            trainTimer.toc();
            val tmp=deliverGradient(compG, fromLearner);
            if (tmp != compG) {
                logger.info(()=>"Learner: Signalling data ready.");
                mm.signalData();
                compG=tmp;
                assert compG.loadSize()==0un : "ApplyLearner: the TG received from fromLearner should have zero size.";
            }
            val start = System.nanoTime();
            reconciler.fillInWeights(currentWeight); // may block
            if (currentWeight.timeStamp > timeStamp) {
                val includeMB = currentWeight.loadSize();
                timeStamp = currentWeight.timeStamp;
                totalMBProcessed += includeMB;
                deserializeWeights(currentWeight.weight);
                weightTimer.addDuration(System.nanoTime()-start);
                logger.info(()=>"Learner: accepted weights " + currentWeight);
            }
            if (testManager != null) testManager.touch();
        } // while !done

        if (testManager != null) testManager.finalize();
        logger.info(()=>"Learner: Exited main loop.");
        logger.notify(()=> "" + trainTimer);
        logger.notify(()=> "" + weightTimer);
    } //learner

}
// vim: shiftwidth=4:tabstop=4:expandtab
