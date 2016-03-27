/**
 * BBuffer.x10
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

import x10.compiler.NonEscaping;

/** A bounded buffer of size N for values of type T. Used to couple 
 * a producer and consumer, where both can progress at different rates
 * but do not wish to get too far ahead of each other.
 * 
 *

 * <p>Implementation Note: uses the (condition, action) model for 
 * application code exposed by rudra.util.Monitor. 
 * @author vj
 */
public class BBuffer[T](N:Int) {
	protected val data:Rail[T];
	protected var nextVal:Int=0n;
	protected var size:Int=0n;
	protected val monitor = new Monitor();
	protected var name:String;
	protected val logger = new Logger(Logger.INFO);
	public def this(N:Int){T haszero}{
		this(N,Zero.get[T]());
	}
	public def this(N:Int, t:T) {
		property(N);
		data = new Rail[T](N, t);
	}
        /** A constructor that permits the initialsize to be set.
            Useful in situations in which you want to consider
            an initialized buffer "pre-seeded" with consumable values.
         */

	public def this(N:Int, t:T, initSize:Int) {
		property(N);
		data = new Rail[T](N, t);
                size = initSize;
	}
	/**
	 * This is the condition for adding an element. May be overridden in subclasses.
	 */
	protected def hasSpace():Boolean = size < N;
	/**
	 * This is the action for adding an element. May be overridden in subclasses.
	 */
	protected def addAndReturn(t:T):T {
		logger.info("Bbuffer: " + this + " assigning at " + nextVal + " size= " + size);
		var nextSlot:Int = nextVal+size;
		if (nextSlot >= N) nextSlot %=N;
		val result = data(nextSlot);
		data(nextSlot)=t;
		size++;
		logger.info(()=>"BBuffer: " + this + " exiting put. ");
		return result;
	}
        protected def add(t:T):void {
		var nextSlot:Int = nextVal+size;
		if (nextSlot >= N) nextSlot %=N;
                data(nextSlot)=t;
		size++;
        }
	@NonEscaping
	final public def setName(s:String) { name=s; }

	/** Returns the value in the slot into which t is added. This
	    can be recycled.
	 */
	public operator this()=(t:T):T{
		logger.info(()=> t + " ==> " + this);
		return monitor.on[T](()=> hasSpace(),()=>addAndReturn(t));
	}
        public def put(t:T):void {
            monitor.on[Unit](()=>hasSpace(), ()=>{add(t);Unit()});
        }
	/**
	 * This is the condition for getting an element. May be overridden in subclasses.
	 */
	protected def hasValue():Boolean = size > 0;
	/**
	 * This is the action for getting an element. May be overridden in subclasses.
	 Takes as argument the value t to be placed in the slot whose value is returned.
	 */
	protected def get_(t:T):T {
		val result = data(nextVal);
		data(nextVal)=t;
		if (++nextVal >= N) nextVal %= N;
		size--;
		return result;
	}
	protected def get_():T {
		val result = data(nextVal);
		if (++nextVal >= N) nextVal %= N;
		size--;
                return result;
	}

	public operator this(t:T):T= monitor.on(()=> hasValue(), ()=>get_(t));
	public operator this():T = monitor.on(()=> hasValue(), ()=>get_());
	public def get():T = monitor.on(()=> hasValue(), ()=>get_());
	public def get(t:T):T = monitor.on(()=> hasValue(), ()=>get_(t));

	/** Returns the next value if the buffer is nonempty, else returns null.
	    Does not block, though it does have to acquire the underlying lock, so 
	    does need to wait for the lock to be available. 
	 */
	public def getIfThere(t:T):T = monitor.atomicBlock[T](()=> hasValue()?get_(t):t);
        //	public def getIfThere():T    = monitor.atomicBlock[T](()=> hasValue()?get_():t);

	/** Returns true iff the buffer has space. Used by producer to determine
	    if invoking put would block.
	 */
	public def hasSpaceNow():Boolean = monitor.atomicBlock(()=>hasValue());

	protected def awaken() { monitor.awaken(); }
	
	public def toString()="<" +(name == null? typeName() + " #"+hashCode() : name) + " " + size + ">";
}
