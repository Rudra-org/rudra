/**
 * Licensed Materials - Property of IBM
 *
 * Rudra Distributed Learning Platform
 *
 *  Copyright IBM Corp. 2016 All Rights Reserved
 */

package rudra;

import x10.util.OptionsParser;
import x10.util.Option;
import x10.util.Team;
import x10.util.concurrent.AtomicBoolean;

import rudra.CodeId;
import rudra.util.Logger;
import rudra.util.Timer;
import rudra.util.SwapBuffer;
import rudra.util.PhasedT;

/**
 Top-level class for the X10-based deep learner.

 @author vj
 */
public class Rudra(config:RudraConfig,
                   CRAB:Boolean, confName:String, noTest:Boolean,
                   weightsFile:String, meanFile:String, 
                   solverType:String, seed:Int, mom:Float,
                   adarho:Float, adaepsilon:Float,

                   nwMode:Int, hardSync:Boolean, 
                   spread:UInt, desiredR:Int, 
                   beatCount:UInt, numXfers:UInt, H:Float, S:UInt,
                   nwSize:Int, 

                   ll:Int, lt:Int, lr:Int, lu:Int, ln:Int)  {
    public static val DEFAULT_SOLVER="sgd";
    public static val DEFAULT_SEED=12345n;
    public static val DEFAULT_MOM = 0.0f;

    public static val DEFAULT_ADADELTA_RHO = 0.95f;
    public static val DEFAULT_ADADELTA_EPSILON = 1e-6f;

    public static val DEFAULT_R = 0n;
    public static val DEFAULT_SPREAD = 10un;
    public static val DEFAULT_NW_MODE = 4n;
    public static val DEFAULT_NW_MODE_STR = "apply";
    public static val DEFAULT_NW_SIZE = 10n;
    public static val DEFAULT_BEAT_COUNT = 10un;
    public static val DEFAULT_NUM_XFERS = 20un;
    public static val DEFAULT_UPDATE_PROB = 0.0f;
    public static val DEFAULT_SUPER_SIZE = 256un;

    public static val DEFAULT_LOG_LEVEL=Logger.WARNING;

    /** Reconciler should drop undelivered gradient when a new network gradient arrives.
     */
    public static val NW_DROP=0n;

    /** Reconciler should accumulate new gradient into undelivered gradient (if any).
     */
    public static val NW_ACCUMULATE=1n;

    /** Reconciler should buffer new gradient. Note: 
        Must have NW_BUFFER < NW_IMMEDIATE < NW_APPLY.
     */
    public static val NW_BUFFER=2n;

    /** Reconciler should apply immediately to the native learner, possibly incurring races.

     */
    public static val NW_IMMEDIATE=3n;

    /** Reconciler should mantain its own native learner and apply new gradient to generate
        new weights.
     */
    public static val NW_APPLY=4n;

    public static val NW_SEND_BROADCAST=5n;
    public static val NW_SEND_RECEIVE=6n;

    static def nwModeFromStr(s:String):Int {
        if (s.equalsIgnoreCase("drop")) return 0n;
        if (s.equalsIgnoreCase("accumulate")) return 1n;
        if (s.equalsIgnoreCase("buffer")) return 2n;
        if (s.equalsIgnoreCase("immediate")) return 3n;
        if (s.equalsIgnoreCase("apply")) return 4n;
        if (s.equalsIgnoreCase("send_broadcast")) return 5n;
        if (s.equalsIgnoreCase("send_receive")) return 6n;
        return 0n;
    }

    val logger = new Logger(lu);
    val nLearners = noTest ? Place.numPlaces() : (Place.numPlaces() - 1);
    val learnerGroup = PlaceGroup.make(nLearners);

    public def run():void {
        if (!noTest) {
            if (Place.numPlaces() < 2) {
                throw new Exception("running with testing enabled requires at least two places!  To run on a single place, specify -noTest");
            }
            val testerPlace = Place.places()(Place.numPlaces()-1);
            at(testerPlace) {
                Learner.initNativeLearnerStatics(config, confName, meanFile,
                    seed, mom, adarho, adaepsilon, ln);
            }
        }

        if (nwMode == NW_SEND_BROADCAST) {
            if (!noTest && Place.numPlaces() < 3) {
                throw new Exception("send_broadcast mode with testing enabled requires at least three places!");
            } else if (Place.numPlaces() < 2) {
                throw new Exception("send_broadcast mode requires at least two places!");
            }
            logger.info(()=>"SB: Starting.");
            new SendBroadcast(config, learnerGroup, hardSync, confName, noTest,
                    weightsFile, meanFile,
                    solverType, seed, mom,
                    adarho, adaepsilon,
                    spread, H, S,
                    ll, lt, ln)
                .run(beatCount, numXfers);
            return;
        } 
        if (nwMode == NW_SEND_RECEIVE) {
            logger.info(()=>"SR: Starting.");
            new SendReceive(config, learnerGroup, numXfers, noTest, confName,
                    weightsFile, meanFile,
                    solverType, seed, mom,
                    adarho, adaepsilon,
                    spread,
                    ll, lt, ln)
                .run();
            return;
        } 

        if ((! hardSync) && (nwMode == NW_APPLY) && desiredR==0n) {
            logger.info(()=>"CAR: Starting.");
        
            new CAR(config, learnerGroup, CRAB, confName, noTest,
                    weightsFile, meanFile,
                    solverType, seed, mom,
                    adarho, adaepsilon,
                    spread, H, S, 
                    ll, lr, lt, ln)
                .run();
            return;
        }

        val team = new Team(learnerGroup);

        // global value, can be referenced across places
        val gCount= new GlobalRef[PhasedT[Int]](new PhasedT[Int](0n,-1n)); 
        val atleastR = new AtLeastRAllReducer(desiredR, team, new Logger(lr), gCount);

        finish for (p in learnerGroup) at(p) async { // this is meant to leak in!!
            val done = new AtomicBoolean(false);
            Learner.initNativeLearnerStatics(config, confName, meanFile, 
                                             seed, mom,
                                             adarho, adaepsilon,
                                             ln);

            val mbSize = config.mbSize;
            val numTrainSamples = config.numTrainSamples;
            val mbPerEpoch = config.mbPerEpoch();
            val maxMB = config.maxMB();

            if (here == Place.FIRST_PLACE) {
                logger.emit("Training with "
                    + nLearners + " places over "
                    + numTrainSamples + " samples, "
                    + config.numEpochs + " epochs, "
                    + mbPerEpoch + " minibatches per epoch = "
                    + maxMB + " minibatches.");
            }

            val nLearner = Learner.makeNativeLearner(config, weightsFile, solverType);
            val networkSize = nLearner.getNetworkSize();
            val size = networkSize+1;
            if (hardSync) {
                if (nwMode != NW_BUFFER) {
                    if (here.id==0) logger.info(()=> "Rudra: Starting HardSync");
                    new HardSync(config, confName, noTest, weightsFile, 
                                 team, new Logger(ll), lr, lt, solverType, nLearner).run();
                } else {
                    if (here.id==0) logger.info(()=> "Rudra: Starting buffered HardSync");
                    val fromL = SwapBuffer.make[TimedGradient](false, new TimedGradient(size));
                    val toL = SwapBuffer.make[TimedGradient](false, new TimedGradient(size));
                    val learner = new HardBufferedLearner(config, confName, noTest, weightsFile,
                                                          team, new Logger(ll), lt, solverType,
                                                          nLearner);
                    val reconciler = new HardBufferedReconciler(config, size,
                                                                new Logger(lr), team);
                    async learner.run(fromL, toL,done);
                    reconciler.run(fromL, toL, done);
                }
                
            } else if (nwMode == NW_APPLY) {
                logger.error(()=>"Rudra: Apply unimplemented for desiredR > 0");
                throw new Exception("Not implemented yet.");
            } else if (nwMode == NW_IMMEDIATE) { // TODO: Fix the reconciler.
                val fromLearner = SwapBuffer.make[TimedGradient](true, new TimedGradient(size));
                val learner = new ImmedLearner(config, confName, noTest, 
                                             spread,
                                             nLearner, team, new Logger(ll), lt, solverType);
                val ir = new ImmedReconciler(config, size, learner, atleastR, new Logger(lr));
                async learner.run(fromLearner, done);
                ir.run(fromLearner, done);              

            } else {
                throw new Exception("Not implemented yet.");
            }
        }
    }
    
    public static def main(args:Rail[String]) {
        val bootLogger = new Logger(Logger.EMIT);
        bootLogger.emit("Hello, Rudra!");
        // Option parser
        val cmdLineParams = new OptionsParser(args,
            [
                Option("-h", "help", "Print help messages"),
                Option("-hard", "hardsync", "Run in hard sync mode"),
                Option("-noTest", "noTestc", "Do not run the inline tester"),
                Option("-CRAB", "Reduce&Bcast", "Continuous Reduce and Broadcast")
            ], 
            [                               
                Option("-f", "config", "Configuration file"),
                Option("-j", "logDirectoryForJob", "Log directory for job, "
                       + "under RUDRA_HOME/LOG"),
                Option("-restart", "weightFile", "Name of file from which to load weights, "
                       + "typically a checkpoint file"),
                Option("-a", "allowedSpread", "Allowed spread in a support set (" 
                       + DEFAULT_SPREAD+"un)"),
                Option("-seed", "seed", "Seed for the random number generator (time of day)"),
                Option("-s", "solver", "Solver (" + DEFAULT_SOLVER+")"),
                Option("-mom", "momentum", "Initial momentum value used in solver=SGD (" 
                       + DEFAULT_MOM + ")"),

                Option("-r", "atLeastR", "When hardsync is not set, allReduce only when "
                       + "at least R MBs are available (" + DEFAULT_R + "n)"),
                Option("-nwModeStr", "networkModeString", 
                       "Value (drop,accumulate,immediate,buffer,apply)"
                       + " determines reconciler action on arrival of new gradient (" 
                       + DEFAULT_NW_MODE_STR+")"),

                // deprecated, use -nwModeStr to make job files more readable
                Option("-nwMode", "networkMode", 
                       "Value (DROP=0,ACCUMULATE=1,IMMEDIATE=2,BUFFER=3,APPLY=4)"
                       + " determines reconciler action on arrival of new gradient (" 
                       + DEFAULT_NW_MODE+"n)"),
                Option("-nwSize", "networkBufferSize", "Size of nw buffer,"
                       + " used only with -nwMode " 
                       + DEFAULT_NW_SIZE + "n"),
                Option("-meanFile", "meanFile", "Path to the mean file, used for"
                       + " processing image data, e.g. for ImageNet"),

                Option("-beatCount", "beatCount", "In SendBroadcast,"
                       + " num updates after which weights are broadcast" 
                       + DEFAULT_BEAT_COUNT + "un)"),
                Option("-updateProb", "updateProbability", "In SendBroadcast,"
                     + " the prob by which an incoming gradient should trigger a weight update" 
                       + DEFAULT_UPDATE_PROB + "un)"),
                Option("-superSize", "superSize", "In SendBroadcast,"
                     + " the target number of gradients (one per observation)"
                       + " that shoud be used to generate new weights ("
                       + DEFAULT_SUPER_SIZE + "un)"),

                Option("-numXfers", "numXfers",   "In SendBroadcast, num xfers that are "
                       + "simultaneously supported by parameter server" 
                       + DEFAULT_NUM_XFERS+"un)"),

                Option("-adrho", "rho",   "The rho multiplier for AdaDelta (" + 
                       + DEFAULT_ADADELTA_RHO+"f)"),
                Option("-adepsilon", "epsilon",   "The epsilon adder for AdaDelta (" + 
                       + DEFAULT_ADADELTA_EPSILON+"f)"),

                // TODO: pass as strings, can never remember the mapping
                Option("-ll", "logLearner",    "log level (INFO=0,WARNING=1,NOTIFY=2,ERROR=3)"
                       + " for Learner (" + DEFAULT_LOG_LEVEL+"n)"),
                Option("-lt", "logTester",     "log level (INFO=0,WARNING=1,NOTIFY=2,ERROR=3)"
                       + " for Tester (" + DEFAULT_LOG_LEVEL+"n)"),
                Option("-lr", "logReconciler", "log level (INFO=0,WARNING=1,NOTIFY=2,ERROR=3)"
                       + " for Reconciler ("+ DEFAULT_LOG_LEVEL+"n)"),
                Option("-lu", "logRudra",      "log level (INFO=0,WARNING=1,NOTIFY=2,ERROR=3)"
                       + " for Rudra ("+ DEFAULT_LOG_LEVEL+"n)"),
                Option("-ln", "logNativeLearner", "log level"
                       + " (INFO=0,WARNING=1,ERROR=2,FATAL=3)"
                       + " for native learner ("+ DEFAULT_LOG_LEVEL+"n)")
            ]);
        val h:Boolean = cmdLineParams("-h"); // help msg
        if (h) {
            Console.OUT.println(cmdLineParams.usage("Usage:\n"));
            return;
        }
        val noTest:Boolean     = cmdLineParams("-noTest"); // do not run the inline tester
        val CRAB:Boolean       = cmdLineParams("-CRAB"); // run CAR with reduce and bcast

        val confName:String   = cmdLineParams("-f", "defaults.conf"); // configuration file
        // log directory, under RUDRA_HOME/LOG/ 
        val jobDir:String     = cmdLineParams("-j", "job" + System.currentTimeMillis()); 
        val weightsFile:String= cmdLineParams("-restart", ""); // weights file 
        val meanFile:String   = cmdLineParams("-meanFile", null as String);


        val solverType:String = cmdLineParams("-s", DEFAULT_SOLVER).trim();
        val seed:Int          = cmdLineParams("-seed", DEFAULT_SEED);
        val mom:Float         = cmdLineParams("-mom", DEFAULT_MOM);

        val hardSync:Boolean  = cmdLineParams("-hard");
        var desiredR:Int      = cmdLineParams("-r", DEFAULT_R);
        var spread:UInt       = cmdLineParams("-a", DEFAULT_SPREAD); 
        var nwMode:Int        = cmdLineParams("-nwMode", DEFAULT_NW_MODE);
        var nwModeStr:String  = cmdLineParams("-nwModeStr", null as String);
        val nwSize:Int        = cmdLineParams("-nwSize", DEFAULT_NW_SIZE);

        val adrho:Float       = cmdLineParams("-adrho", DEFAULT_ADADELTA_RHO);
        val adepsilon:Float   = cmdLineParams("-adepsilon", DEFAULT_ADADELTA_EPSILON);

        var beatCount:UInt    = cmdLineParams("-beatCount", DEFAULT_BEAT_COUNT);
        val numXfers:UInt     = cmdLineParams("-numXfers", DEFAULT_NUM_XFERS);

        val H:Float           = cmdLineParams("-updateProb", DEFAULT_UPDATE_PROB);
        val S:UInt            = cmdLineParams("-superSize", DEFAULT_SUPER_SIZE);

        val ll:Int            = cmdLineParams("-ll", DEFAULT_LOG_LEVEL);
        val lt:Int            = cmdLineParams("-lt", DEFAULT_LOG_LEVEL);
        val lr:Int            = cmdLineParams("-lr", DEFAULT_LOG_LEVEL);
        val lu:Int            = cmdLineParams("-lu", DEFAULT_LOG_LEVEL);
        val ln:Int            = cmdLineParams("-ln", DEFAULT_LOG_LEVEL);

        if (nwModeStr!=null) nwMode=nwModeFromStr(nwModeStr);

        if (hardSync) {
            if (desiredR > 0)  {
                Console.OUT.println("Both hardsync (-hard) and desiredR (-r)"
                  + " are set. Hardsync takes priority, desiredR set to 0.");
                desiredR=0n;
            }
            if (nwMode != Rudra.NW_BUFFER)  {
                Console.OUT.println("Hardsync (-hard) is set. "
                                    + "Only nwMode= " + Rudra.NW_BUFFER 
                                    + " makes sense. Ignoring.");
                nwMode=NW_DROP;
            }
            if (spread > 1un) {
                Console.OUT.println("Hardsync (-hard) is set."
                                    +" spread is irrelevant, changed to 1");
                spread=1un;
            }
        }

        val config = RudraConfig.readFromFile(confName);
        config.jobID = jobDir;

        // echo command line parameters
        bootLogger.emit("Running on " + Place.numPlaces() + " places.");
        bootLogger.emit("Running with code |" + CodeId.commitHash+ "|");
        bootLogger.emit("rudra -f |" + confName  + "|"
                        + "\n\t -j " + jobDir + " -restart |" + weightsFile  + "|"
                        + " -meanFile |" + meanFile + "|"
                        + "\n\t -s |" + solverType + "| -seed " + seed 
                        + " -mom " + mom

                        + ((adrho != DEFAULT_ADADELTA_RHO) ? " -adrho " + adrho : "")
                        + ((adepsilon != DEFAULT_ADADELTA_RHO) ? " -adepsilon " + adepsilon : "")

                        + "\n\t -a " + spread  
                        + (hardSync?" -hard":"") + " -nwMode " + nwMode 
                        + (noTest?" -noTest":"") 
                        + " -nwSize " + nwSize + " -r " + desiredR
                        + " -beatCount " + beatCount + " -numXfers " + numXfers
                        + " -updateProb " + H + " -superSize " + S + (CRAB?" -CRAB" : "")
                        + "\n\t" 
                        + " -ll " + Logger.levelString(ll)
                        + " -lt " + Logger.levelString(lt) 
                        + " -lr " + Logger.levelString(lr) 
                        + " -lu " + Logger.levelString(lu) 
                        + " -ln " + Logger.levelString(ln));
        val rudra = new Rudra(config, CRAB, confName, noTest,
                              weightsFile, meanFile,
                              solverType, seed, mom,
                              adrho, adepsilon,
                              nwMode, hardSync, 
                              spread, desiredR,
                              beatCount, numXfers, H, S, 
                              nwSize, 

                              ll, lt, lr, lu, ln);
        val startTime = System.currentTimeMillis();
        rudra.run();
        val runTime = (System.currentTimeMillis()-startTime);
        bootLogger.emit("Time=" + Timer.time(runTime) + ". \n Goodbye!\n");
    }
}
// vim: shiftwidth=4:tabstop=4:expandtab
