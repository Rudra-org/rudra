/**
 *
 * TimedGradient.x10
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

public class TimedGradient(size:Long) { // mutated in place, hence fields are vars.
    var timeStamp:UInt=0un;
    var grad:Rail[Float] = null;
    def this(size:Long) { this(size, new Rail[Float](size));}
    def this(size:Long, rail:Rail[Float]) {
        property(size);
        this.grad=rail;
    }
    def loadSize():UInt=grad(size-1) as UInt;
    def setLoadSize(l:UInt):void{
        grad(size-1)=l as Float;
    }
    def addIn(g:TimedGradient):void {
        assert size==g.size  : "TimedGradients of different sizes?!?!";
        if (g.loadSize() > 0un)
            for (i in  0..(size-1)) grad(i) += g.grad(i);
    }
    def clear() {
        for (i in  0..(size-1)) grad(i) = 0f;
    }
    def calcHash():Float{
        var result:Float=0.0f;
        for (x in grad) result+=x;
        return result/grad.size;
    }
    public def toString():String = "<TG #" + hashCode() + " load="+ calcHash()+",size="+(grad(size-1) as Long)+",time="+timeStamp+">";
}
