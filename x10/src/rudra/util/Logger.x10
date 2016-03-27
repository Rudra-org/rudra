/**
 * Logger.x10
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

package rudra.util;

import x10.xrx.Runtime;

public class Logger(level:Int) {
    /**
       The most detailed level of output. Use this to mark the key events
       in your control flow for the log. (Sometimes called DEBUG level.)

       When debugging, run with level=INFO.

     */
    public static val INFO=0n;

    /** Use this mark run-time conditions that are not fatal but indicate a
        problem (performance, functionaity) that should be looked at.

        Usually programs should be run with level=WARNING. At this level,
       warnings, notifications and errors will print. 
     */
    public static val WARNING=1n;    

    /**
       Use this to mark messages of interest to the person running the program,
       such as timing information. 
     */
    public static val NOTIFY=2n;    

    /**
       Use this to mark errors in the program. Use assert's when u want backtrace logs
       at the point where the error has occurred. 

       Errors cannot be masked. Run programs with level=ERROR when u just want to know
       if the program works. 

     */
    public static val ERROR=3n;

    /**
       Use this to mark output of interest to the person running the program that should
       not be masked. Same as ERROR level but avoids the pejorative connotation of "error". 
     */
    public static val EMIT=3n;

    public def levelString():String=levelString(level);
    public static def levelString(level:Int):String {
        switch (level) {
        case 0n: return "INFO";
        case 1n: return "WARNING";
        case 2n: return "NOTIFY";
        case 3n: return "ERROR/EMIT";
        }
        return "??";
    }

    public static def nativeLevelString(level:Int):String {
        switch (level) {
        case 0n: return "INFO";
        case 1n: return "WARNING";
        case 2n: return "ERROR";
        case 3n: return "FATAL";
        }
        return "??";
    }

    //    public val baseTime=System.currentTimeMillis(); // time of creation

    def out(s:String) { 
        val time =  System.nanoTime(); // currentTimeMillis()-baseTime;
        //        val seconds = (time / (1000*1000*1000));
        //        val fraction = time % (1000*1000*1000);
        Console.OUT.println("[" + time // seconds + " " + fraction 
                            +", place=" + here.id+" worker=" + Runtime.workerId() + "] " + s);
    }
    public  def info(s:()=>String)            { if (INFO >=level) out(s());}
    public  def info(s:String)                { if (INFO>=level)  out(s);}
    public  def info[T](s:(T)=>String, t:T)   { if (INFO>=level)  out(s(t));}

    public  def warning(s:()=>String)         { if (WARNING>=level) out(s());}
    public  def warning[T](s:(T)=>String, t:T){ if (WARNING>=level) out(s(t));}
    public  def warning(s:String)             { if (WARNING >=level)out(s);}

    public  def notify(s:()=>String)          { if (NOTIFY>=level) out(s());}
    public  def notify[T](s:(T)=>String, t:T) { if (NOTIFY>=level) out(s(t));}
    public  def notify(s:String)              { if (NOTIFY>=level) out(s);}

    public  def error(s:()=>String)           { if (ERROR>=level) out(s());}
    public  def error[T](s:(T)=>String, t:T)  { if (ERROR>=level) out(s(t));}
    public  def error(s:String)               { if (ERROR >=level)out(s);}

    public  def emit(s:()=>String)            { if (EMIT>=level) out(s());}
    public  def emit[T](s:(T)=>String, t:T)   { if (EMIT>=level) out(s(t));}
    public  def emit(s:String)                { if (EMIT>=level)out(s);}


}
// vim: shiftwidth=4:tabstop=4:expandtab
