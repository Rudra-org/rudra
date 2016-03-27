/**
 *
 * GlobalTimedWeight.x10
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

public class GlobalTimedWeight(networkSize:Long) implements TimedWeightI { // mutated in place, hence fields are vars.
    var timeStamp:UInt=0un;
    var size:UInt=0un;
    var weight:GlobalRail[Float] = GlobalRail(new Rail[Float](networkSize));
    public def weightRail():Rail[Float]=weight();
    public def loadSize():UInt=size;
    public def setLoadSize(l:UInt):void{
        size=l;
    }
    public def timeStamp():UInt = timeStamp;
    public def setTimeStamp(u:UInt):void {
        timeStamp=u;
    }
    def calcHash():Float{
        var result:Float=0.0f;
        val wweight = weight();
        for (x in wweight) result+=x;
        return result/wweight.size;
    }
    public def toString():String = 
         (here==weight.rail.home)
       ? ("<GTG #" + hashCode()+" load="+ calcHash()+", size="+loadSize()+", time="+timeStamp+">" )
       : ("<Remote GTG #" + hashCode()+ " home=" + weight.rail.home + ", time="+timeStamp+">");

}
