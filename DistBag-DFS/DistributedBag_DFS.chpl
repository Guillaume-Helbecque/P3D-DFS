// "opt: ?T = none" to declare optional argument

module DistributedBag_DFS
{
  public use Collection;
  use BlockDist;
  private use CTypes;
  use IO only channel;

  use Random;
  use Time;
  use List;

  /*
    Below are segment statuses, which is a way to make visible to outsiders the
    current ongoing operation. In segments, we use test-and-test-and-set spinlocks
    to allow polling for other conditions other than lock state. `sync` variables
    do not offer a means of acquiring in a non-blocking way, so this is needed to
    ensure better 'best-case' and 'average-case' phases.
  */
  private param STATUS_UNLOCKED: uint = 0;
  private param STATUS_ADD: uint      = 1;
  private param STATUS_REMOVE: uint   = 2;
  private param STATUS_LOOKUP: uint   = 3;
  private param STATUS_BALANCE: uint  = 4;

  /*
    Below are statuses specific to the work stealing algorithm. These allow the
    shepherd tasks to know when its sub-helpers finish and the end status of their
    work stealing attempt.
  */
  private param WS_INITIALIZED            = -1;
  private param WS_FINISHED_WITH_NO_WORK  =  0;
  private param WS_FINISHED_WITH_WORK     =  1;

  /*
    The phases for operations. An operation is composed of multiple phases,
    where they make a full pass searching for ideal conditions, then less-than-ideal
    conditions; this is required to ensure maximized parallelism at all times, and
    critical to good performance, especially when a node is oversubscribed.
  */
  private param ADD_BEST_CASE         = 0;
  private param ADD_AVERAGE_CASE      = 1;
  private param REMOVE_SIMPLE         = 2;
  private param REMOVE_LOCAL_STEAL    = 3;
  private param REMOVE_GLOBAL_STEAL   = 4;
  private param REMOVE_STEAL_REQUEST  = 5;

  private param REMOVE_SUCCESS   =  1;
  private param REMOVE_FAST_EXIT =  0; // 0
  private param REMOVE_FAIL      = -1;

  /*
    The initial amount of elements in an unroll block. Each successive unroll block
    is double the size of it's predecessor, allowing for better locality for when
    there are larger numbers of elements. The better the locality, the better raw
    performance and easier it is to redistribute work.
  */
  config const distributedBagInitialBlockSize: int = 102400;
  /*
    To prevent stealing too many elements (horizontally) from another node's segment
    (hence creating an artificial load imbalance), if the other node's segment has
    less than a certain threshold (see :const:`distributedBagWorkStealingMemCap`) but above
    another threshold (see :const:`distributedBagWorkStealingMinElems`), we steal a percentage of their
    elements, leaving them with majority of their elements. This way, the amount the
    other segment loses is proportional to how much it owns, ensuring a balance.
  */
  config const distributedBagWorkStealingRatio: real = 0.25;
  /*
    The maximum amount of work to steal from a horizontal node's segment. This
    should be set to a value, in megabytes, that determines the maximum amount of
    data that should be sent in bulk at once. The maximum number of elements is
    determined by: (:const:`distributedBagWorkStealingMemCap` * 1024 * 1024) / sizeof(eltType).
    For example, if we are storing 8-byte integers and have a 1MB limit, we would
    have a maximum of 125,000 elements stolen at once.
  */
  config const distributedBagWorkStealingMemCap: real = 1.0;
  /*
    The minimum number of elements a horizontal segment must have to become eligible
    to be stolen from. This may be useful if some segments produce less elements than
    others and should not be stolen from.
  */
  config const distributedBagWorkStealingMinElems: int = 1;
  /*
    The maximum amount of elements in an unroll block. This is crucial to ensure memory
    usage does not rapidly grow out of control.
  */
  config const distributedBagMaxBlockSize: int = 1024 * 1024;

  /*
    Reference coun ter for DistributedBag
  */
  class DistributedBagRC
  {
    type eltType;
    var _pid: int;

    proc deinit()
    {
      coforall loc in Locales do on loc {
        delete chpl_getPrivatizedCopy(unmanaged DistributedBagImpl(eltType), _pid);
      }
    }
  }

  /*
    A parallel-safe distributed multiset implementation that scales in terms of
    nodes, processors per node (PPN), and workload; The more PPN, the more segments
    we allocate to increase raw parallelism, and the larger the workload the better
    locality (see :const:`distributedBagInitialBlockSize`). This data structure is unordered and employs
    its own work-stealing algorithm, and provides a means to obtain a privatized instance of
    the data structure for maximized performance.
  */
  pragma "always RVF"
  record DistBag_DFS
  {
    type eltType;

    // This is unused, and merely for documentation purposes. See '_value'.
    /*
      The implementation of the Bag is forwarded. See :class:`DistributedBagImpl` for
      documentation.
    */
    var _impl: unmanaged DistributedBagImpl(eltType)?;

    // Privatized id
    var _pid: int = -1;

    // Reference Counting
    var _rc: shared DistributedBagRC(eltType);

    proc init(type eltType, targetLocales = Locales)
    {
      this.eltType = eltType;
      this._pid = (new unmanaged DistributedBagImpl(eltType, targetLocales = targetLocales)).pid;
      this._rc = new shared DistributedBagRC(eltType, _pid = _pid);
    }

    inline proc _value
    {
      if (_pid == -1) then halt("DistBag is uninitialized.");
      return chpl_getPrivatizedCopy(unmanaged DistributedBagImpl(eltType), _pid);
    }

    proc readThis(f) throws {
      compilerError("Reading a DistBag is not supported");
    }

    // Write the contents of DistBag to a channel.
    proc writeThis(ch) throws {
      ch.write("[");
      var size = this.getSize();
      for (i,iteration) in zip(this, 0..<size) {
        ch.write(i);
        if (iteration < size-1) then ch.write(", ");
      }
      ch.write("]");
    }

    forwarding _value;
  }

  class DistributedBagImpl : CollectionImpl
  {
    var targetLocDom: domain(1);
    var targetLocales: [targetLocDom] locale; // the locales to allocate bags for and load balance across.
    var pid: int = -1;

    // Node-local fields below. These fields are specific to the privatized instance.
    // To access them from another node, make sure you use 'getPrivatizedThis'
    var bag: unmanaged Bag(eltType)?;

    proc init(type eltType, targetLocales: [?targetLocDom] locale = Locales)
    {
      super.init(eltType);

      this.targetLocDom  = targetLocDom;
      this.targetLocales = targetLocales;

      complete();

      this.pid = _newPrivatizedClass(this);
      this.bag = new unmanaged Bag(eltType, this);
    }

    proc init(other, pid, type eltType = other.eltType)
    {
      super.init(eltType);

      this.targetLocDom  = other.targetLocDom;
      this.targetLocales = other.targetLocales;
      this.pid           = pid;

      complete();

      this.bag = new unmanaged Bag(eltType, this);
    }

    proc deinit()
    {
      delete bag;
    }

    proc dsiPrivatize(pid)
    {
      return new unmanaged DistributedBagImpl(this, pid);
    }

    proc dsiGetPrivatizeData()
    {
      return pid;
    }

    inline proc getPrivatizedThis
    {
      return chpl_getPrivatizedCopy(this.type, pid);
    }

    iter targetLocalesNotHere()
    {
      foreach loc in targetLocales {
        if (loc != here) then yield loc;
      }
    }

    // Insert an element in a segment of this node's bag.
    override proc add(elt: eltType): bool
    {
      return bag!.add(elt);
    }

    // Insert an element in the calling thread's segment of this node's bag.
    proc add(elt: eltType, tid: int): bool
    {
      return bag!.add(elt, tid);
    }

    /*
      Insert elements in bulk in the calling thread's segment of this node's bag.
      If the node's bag rejects an element, we cease to offer more. We return the
      number of elements successfully added to this data structure.
    */
    proc addBulk(elts, tid: int): int
    {
      var successful: int;
      for elt in elts {
        if !add(elt, tid) then break;

        successful += 1;
      }

      return successful;
    }

    /*
      Remove an element from this node's bag. The order in which elements are removed
      are not guaranteed to be the same order it has been inserted. If this node's
      bag is empty, it will attempt to steal elements from bags of other nodes.
    */
    override proc remove(): (bool, eltType)
    {
      return bag!.remove();
    }

    /*
      Remove an element from the calling thread's segment of this node's bag.
      If the thread's segment is empty, it will attempt to steal an element from
      the segment of another thread or node.
    */
    proc remove(tid: int): (int, eltType)
    {
      return bag!.remove(tid);
    }

    /*
      Obtain the number of elements held in all bags across all nodes. This method
      is best-effort and can be non-deterministic for concurrent updates across nodes,
      and may miss elements or even count duplicates resulting from any concurrent
      insertion or removal operations.
    */
    override proc getSize(): int
    {
      var sz: atomic int;
      coforall loc in targetLocales do on loc {
        var instance = getPrivatizedThis;
        forall segmentIdx in 0..#here.maxTaskPar {
          sz.add(instance.bag!.segments[segmentIdx].nElems.read():int);
        }
      }

      return sz.read();
    }

    /*
      Performs a lookup to determine if the requested element exists in this bag.
      This method is best-effort and can be non-deterministic for concurrent
      updates across nodes, and may miss elements resulting from any concurrent
      insertion or removal operations.
    */

    // UNUSED (contains)
    /* override proc contains(elt: eltType): bool
    {
    var foundElt: atomic bool;
    forall elem in getPrivatizedThis {
    if (elem == elt) then foundElt.write(true);
  }
  return foundElt.read();
  } */

    /*
      Clear all bags across all nodes in a best-effort approach. Elements added or
      moved around from concurrent additions or removals may be missed while clearing.
    */
    /* override proc clear(): void
    {
      var localThis = getPrivatizedThis;
      coforall loc in localThis.targetLocales do on loc {
        var instance = getPrivatizedThis;
        forall segmentIdx in 0..#here.maxTaskPar {
          ref segment = instance.bag!.segments[segmentIdx];

          if segment.acquireIfNonEmpty(STATUS_REMOVE) {
            delete segment.block;

            segment.block = nil;
            segment.nElems.write(0);
            segment.releaseStatus();
          }
        }
      }
    } */

    /*
      Triggers a more static approach to load balancing, fairly redistributing all
      elements fairly for bags across nodes. The result will result in all segments
      having roughly the same amount of elements.
      .. note::
      This method is very heavy-weight in that it should not be called too
      often. Dynamic work stealing handles cases where there is a relatively fair
      distribution across majority of nodes, but this should be called when you have
      a severe imbalance, or when you have a smaller number of elements to balance.
      Furthermore, while this operation is parallel-safe, it should be called from at
      most one task.
    */

    // UNUSED (balance)
    /* proc balance(): void
    {
      var localThis = getPrivatizedThis;
      // Phase 1: Acquire all locks from first node and segment to last
      // node and segment (our global locking order...)
      for loc in localThis.targetLocales do on loc {
        var instance = getPrivatizedThis;
        for segmentIdx in 0..#here.maxTaskPar {
          ref segment = instance.bag!.segments[segmentIdx];
          segment.acquire(STATUS_BALANCE);
        }
      }

      // Phase 2: Concurrently redistribute elements from segments which contain
      // more than the computed average.
      coforall segmentIdx in 0..#here.maxTaskPar {
        var nSegmentElems: [0..#localThis.targetLocales.size] int;
        var locIdx = 0;
        for loc in localThis.targetLocales do on loc {
          var nElems = getPrivatizedThis.bag!.segments[segmentIdx].nElems:int;
          nSegmentElems[locIdx] = nElems;
          locIdx += 1;
        }

        // Find the average and the excess. The excess is calculated as the amount
        // of elements a segment has over the average, which is used to calculate
        // the buffer size for each segment.
        var total = (+ reduce nSegmentElems);
        var avg = total / locIdx;
        var excess: int;
        for nElems in nSegmentElems {
          if (nElems > avg) then excess += nElems - avg;
        }

        // Allocate buffer, which holds the 'excess' elements for redistribution.
        // Then fill it.
        var buffer = c_malloc(eltType, excess);
        var bufferOffset = 0;
        for loc in localThis.targetLocales do on loc {
          var average = avg;
          ref segment = getPrivatizedThis.bag!.segments[segmentIdx];
          var nElems = segment.nElems:int;
          if (nElems > average) {
            var nTransfer = nElems - average;
            var tmpBuffer = buffer + bufferOffset;
            segment.transferElements(tmpBuffer, nTransfer, buffer.locale.id);
            bufferOffset += nTransfer;
          }
        }

        // With the excess elements, redistribute it...
        bufferOffset = 0;
        for loc in localThis.targetLocales do on loc {
          var average = avg;
          ref segment = getPrivatizedThis.bag!.segments[segmentIdx];
          var nElems = segment.nElems:int;
          if (average > nElems) {
            var give = average - nElems;
            var arr: [1..give] eltType;
            on bufferOffset {
              var tmpBuffer = buffer;
              for i in 1..give {
                arr[i] = tmpBuffer[bufferOffset];
                bufferOffset += 1;
              }
            }
            for i in 1..give {
              segment.addElement(arr[i]);
            }
          }
        }

        // Lastly, if there are items left over, just add them to our locale's segment.
        if (excess > bufferOffset) {
          ref segment = localThis.bag!.segments[segmentIdx];
          var nLeftOvers = excess - bufferOffset;
          var tmpBuffer = buffer + bufferOffset;
          segment.addElementsPtr(tmpBuffer, nLeftOvers, buffer.locale.id);
        }

        c_free(buffer);
      }

      // Phase 3: Release all locks from first node and segment to last node and segment.
      for loc in localThis.targetLocales do on loc {
        var instance = getPrivatizedThis;
        for segmentIdx in 0..#here.maxTaskPar {
          ref segment = instance.bag!.segments[segmentIdx];
          segment.releaseStatus();
        }
      }
    } */

    /*
      Iterate over each bag in each node. To avoid holding onto locks, we take
      a snapshot approach, increasing memory consumption but also increasing parallelism.
      This allows other concurrent, even mutating, operations while iterating,
      but opens the possibility to iterating over duplicates or missing elements
      from concurrent operations.
      .. note::
      `zip` iteration is not yet supported with rectangular data structures.
      .. warning::
      Iteration takes a snapshot approach, and as such can easily result in a
      Out-Of-Memory issue. If the data structure is large, the user is doubly advised to use
      parallel iteration, for both performance and memory benefit.
    */

    // UNUSED (these)
    /* override iter these(): eltType
    {
      for loc in targetLocales {
        for segmentIdx in 0..#here.maxTaskPar {
          // The size of the snapshot is only known once we have the lock.
          var dom : domain(1) = {0..-1};
          var buffer : [dom] eltType;

          on loc {
            ref segment = getPrivatizedThis.bag!.segments[segmentIdx];

            if segment.acquireIfNonEmpty(STATUS_LOOKUP) {
              dom = {0..#segment.nElems.read():int};
              var block = segment.headBlock;
              var idx = 0;
              while (block != nil) {
                for i in 0..#block!.size {
                  buffer[idx] = block!.elems[i];
                  idx += 1;
                }
                block = block!.next;
              }
              segment.releaseStatus();
            }
          }

          // Process this chunk if we have one...
          foreach elem in buffer {
            yield elem;
          }
        }
      }
    } */

    // UNUSED (these)
    /* iter these(param tag : iterKind) where tag == iterKind.leader
    {
      coforall loc in targetLocales do on loc {
        var instance = getPrivatizedThis;
        coforall segmentIdx in 0..#here.maxTaskPar {
          ref segment = instance.bag!.segments[segmentIdx];

          if segment.acquireIfNonEmpty(STATUS_LOOKUP) {
            // Create a snapshot...
            var block = segment.headBlock;
            var bufferSz = segment.nElems.read():int;
            var buffer = c_malloc(eltType, bufferSz);
            var bufferOffset = 0;

            while (block != nil) {
              if (bufferOffset + block!.size > bufferSz) {
                halt("DistributedBag Internal Error: Snapshot attempt with bufferSz(", bufferSz, ") with offset bufferOffset(", bufferOffset + block!.size, ")");
              }
              __primitive("chpl_comm_array_put", block!.elems[0], here.id, buffer[bufferOffset], block!.size);
              bufferOffset += block!.size;
              block = block!.next;
            }

            // Yield this chunk to be process...
            segment.releaseStatus();
            yield (bufferSz, buffer);
            c_free(buffer);
          }
        }
      }
    } */

    // UNUSED (these)
    /* iter these(param tag : iterKind, followThis) where tag == iterKind.follower
    {
      var (bufferSz, buffer) = followThis;
      foreach i in 0..#bufferSz {
        yield buffer[i];
      }
    } */
  }

  /*
    We maintain a multiset 'bag' per node. Each bag keeps a handle to it's parent,
    which is required for work stealing.
  */
  class Bag
  {
    type eltType;

    // A handle to our parent 'distributed' bag, which is needed for work stealing.
    var parentHandle: borrowed DistributedBagImpl(eltType);

    /*
      Helps evenly distribute and balance placement of elements in a best-effort
      round-robin approach. In the case where we have parallel enqueues or dequeues,
      they are less likely overlap with each other. Furthermore, it increases our
      chance to find our 'ideal' segment.
    */
    var startIdxEnq: atomic uint;
    var startIdxDeq: atomic uint;

    var steal_request: atomic bool = false;
    var steal_status: atomic bool = false;
    var stealer_locId: atomic int;
    var stealer_segId: atomic int;

    var end_exploration: atomic bool = false;

    var request_status$: sync bool = true; // full

    /*
      This vector stores the locale indices, from the last visited to the most.
      It is usefull to optimize the global WS mechanism.
    */
    var visited_loc: [0..#numLocales] int = 0..#numLocales;

    /*
      If a task makes 2 complete passes (1 best-case, 1 average-case) and has not
      found enough items, then it may attempt to balance the load distribution.
      Furthermore, if a task is waiting on a load balance, it may piggyback on the
      result.
    */
    var loadBalanceInProgress: atomic bool;
    var loadBalanceResult: atomic bool;

    var segments: [0..#here.maxTaskPar] Segment(eltType);

    var globalStealInProgress: atomic bool = false;

    inline proc nextStartIdxEnq
    {
      return (startIdxEnq.fetchAdd(1) % here.maxTaskPar:uint):int;
    }

    inline proc nextStartIdxDeq
    {
      return (startIdxDeq.fetchAdd(1) % here.maxTaskPar:uint):int;
    }

    proc init(type eltType, parentHandle)
    {
      this.eltType = eltType;
      this.parentHandle = parentHandle;
    }

    proc deinit()
    {
      forall segment in segments {
        delete segment.block;
      }
    }

    /*
      This iterator is intented to select victim(s) in work-stealing strategies,
      according to the specified policy. By default, the 'rand' strategy is chosen and
      the calling thread/locale cannot be chosen. We can specify how many tries we want,
      by default, only 1 is performed.
    */
    iter victim(const T: string, const callerId: int, const mode: string = "rand", const tries: int = 1): int
    {
      var count: int = 0;
      var max_victim: int;

      if (T == "thread") {
        max_victim = here.maxTaskPar;
      } else if (T == "locale") {
        max_victim = numLocales;
      } else halt("DistributedBag internal error: Wrong victim's type");

      select mode {
        // In the 'ring' strategy, threads/locales are selected in a round-robin fashion.
        when "ring" {
          var id = (callerId + 1) % max_victim;

          while ((count <= max_victim-1) && (count < tries)) {
            // The following "if" is not necessary, only for security.
            if (id != callerId) {
              yield id;
              count += 1;
            }
            id = (id + 1) % max_victim;
          }
        }
        // In the 'rand' strategy, threads/locales are randomly selected.
        when "rand" {
          var id: int = 0;
          var victims: [0..#max_victim] int;
          permutation(victims);

          while ((count < max_victim-1) && (count <= tries)) {
            if (victims[id] != callerId) {
              yield victims[id];
              count += 1;
            }
            id += 1;
          }
        }
        otherwise halt("DistributedBag internal error: Wrong victim choice policy");
      }
    }

    // Add an element in a (indeterminate) segment
    proc add(elt: eltType): bool
    {
      var startIdx = nextStartIdxEnq: int;
      var phase = ADD_BEST_CASE;

      while true {
        select phase {

          // Pass 1: Best Case
          // Find a segment that is unlocked and attempt to acquire it. As we are adding
          // elements, we don't care how many elements there are, just that we find
          // some place to add ours.
          when ADD_BEST_CASE {
            for offset in 0..#here.maxTaskPar {
              ref segment = segments[(startIdx + offset) % here.maxTaskPar];

              // Attempt to acquire...
              if segment.acquireWithStatus(STATUS_ADD) {
                segment.addElement(elt);
                segment.releaseStatus();
                return true;
              }
            }

            phase = ADD_AVERAGE_CASE;
          }

          // Pass 2: Average Case
          // Find any segment (locked or unlocked) and make an attempt to acquire it.
          when ADD_AVERAGE_CASE {
            ref segment = segments[startIdx];

            while true {
              select segment.currentStatus {
                // Quick acquire...
                when STATUS_UNLOCKED {
                  if segment.acquireWithStatus(STATUS_ADD) {
                    segment.addElement(elt);
                    segment.releaseStatus();
                    return true;
                  }
                }
              }
              chpl_task_yield();
            }
          }
        }
      }

      halt("DistributedBag Internal Error: DEADCODE.");
    }

    /*
      Insertion operation.
    */
    proc add(elt: eltType, const threadId: int): bool
    {
      segments[threadId].addElement(elt);

      return true;
    }

  proc remove(): (bool, eltType)
  {
    var startIdx = nextStartIdxDeq;
    var idx = startIdx;
    var iterations = 0;
    var phase = REMOVE_SIMPLE;
    var backoff = 0;

    while true {
      select phase {

        // Pass 1: Best Case
        // Find the first bucket that is both unlocked and contains elements. This is
        // extremely helpful in the case where we have a good distribution of elements
        // in each segment.
        when REMOVE_SIMPLE {
          while (iterations < here.maxTaskPar) {
            ref segment = segments[idx];

            // Attempt to acquire...
            if (!segment.isEmpty && segment.acquireWithStatus(STATUS_REMOVE)) {
              var (hasElem, elem): (bool, eltType) = segment.takeElement();
              segment.releaseStatus();

              if hasElem {
                return (hasElem, elem);
              }
            }

            iterations += 1;
            idx = (idx + 1) % here.maxTaskPar;
          }

          phase = REMOVE_LOCAL_STEAL;
        }

        // Pass 2: Average Case
        // Find the first bucket containing elements. We don't care if it is locked
        // or unlocked this time, just that it contains elements; this handles majority
        // of cases where we have elements anywhere in any segment.
        when REMOVE_LOCAL_STEAL {
          while (iterations < here.maxTaskPar) {
            ref segment = segments[idx];

            // Attempt to acquire...
            while !segment.isEmpty {
              if (segment.isUnlocked && segment.acquireWithStatus(STATUS_REMOVE)) {
                var (hasElem, elem): (bool, eltType) = segment.takeElement();
                segment.releaseStatus();

                if hasElem {
                  return (hasElem, elem);
                }
              }

              // Backoff
              chpl_task_yield();
            }

            iterations += 1;
            idx = (idx + 1) % here.maxTaskPar;
          }

          phase = REMOVE_GLOBAL_STEAL;
        }

        // Pass 3: Worst Case
        // After two full iterations, we're sure the queue is full at this point, so we
        // can attempt to steal work from other nodes. In this pass, we find *any* segment
        // and if it is empty, we attempt to become the work-stealer; if someone else is the
        // current work stealer we assist them instead and lift an element for ourselves.
        // Furthermore, in this phase we loop indefinitely until we are 100% certain it is
        // empty or we get an item, so introduce some backoff here.
        when REMOVE_GLOBAL_STEAL {
          while true {
            ref segment = segments[idx];

            select segment.currentStatus {
              // Quick acquire
              when STATUS_UNLOCKED {
                if segment.acquireWithStatus(STATUS_REMOVE) {
                  // We're lucky; another element has been added to the current segment,
                  // take it and leave like normal...
                  if !segment.isEmpty {
                    var (hasElem, elem): (bool, eltType) = segment.takeElement('t');
                    segment.releaseStatus();
                    return (hasElem, elem);
                  }

                  if (parentHandle.targetLocales.size == 1) {
                    segment.releaseStatus();
                    var default: eltType;
                    return (false, default);
                  }

                  // Attempt to become the sole work stealer for this node. If we
                  // do not, we spin until they finish. We need to release the lock
                  // on our segment so our segment may be load balanced as well.
                  if loadBalanceInProgress.testAndSet() {
                    segment.releaseStatus();

                    loadBalanceInProgress.waitFor(false);
                    var notEmpty = loadBalanceResult.read();
                    if !notEmpty {
                      var default: eltType;
                      return (false, default);
                    }

                    // Reset our phase and scan for more elements...
                    phase = REMOVE_SIMPLE;
                    break;
                  }

                  // We are the sole work stealer, and so it is our responsibility
                  // to balance the load for our node. We fork-join new worker
                  // tasks that will check horizontally across each node (as in
                  // across each segment with the same index), and vertically across
                  // each segment (each segment in a node). Horizontally, we steal
                  // at most a % of work from other nodes to give to ourselves.
                  // As load balancer, we also are the only one who knows whether
                  // or not all bags are empty.
                  var isEmpty: atomic bool;
                  isEmpty.write(true);
                  segment.releaseStatus();
                  coforall segmentIdx in 0..#here.maxTaskPar {
                    var stolenWork: [{0..#numLocales}] (int, c_ptr(eltType));
                    coforall loc in parentHandle.targetLocalesNotHere() {
                      if (loc != here) then on loc {
                        // As we jumped to the target node, 'localBag' returns
                        // the target's bag that we are attempting to steal from.
                        var targetBag = parentHandle.bag;

                        // Only proceed if the target is not load balancing themselves...
                        if !targetBag!.loadBalanceInProgress.read() {
                          ref targetSegment = targetBag!.segments[segmentIdx];

                          // As we only care that the segment contains data,
                          // we test-and-test-and-set until we gain ownership.
                          while (targetSegment.nElems.read() >= distributedBagWorkStealingMinElems) {
                            var backoff = 0;
                            if ((targetSegment.currentStatus == STATUS_UNLOCKED) && targetSegment.acquireWithStatus(STATUS_REMOVE)) {
                              // Sanity check: ensure segment did not fall under minimum since last check
                              if (targetSegment.nElems.read() < distributedBagWorkStealingMinElems) {
                                targetSegment.releaseStatus();
                                break;
                              }

                              extern proc sizeof(type x): c_size_t;
                              // We steal at most 1MB worth of data. If the user has less than that, we steal a %, at least 1.
                              const mb = distributedBagWorkStealingMemCap * 1024 * 1024;
                              var toSteal = max(distributedBagWorkStealingMinElems, min(mb / sizeof(eltType), targetSegment.nElems.read() * distributedBagWorkStealingRatio)):int;

                              // Allocate storage...
                              on stolenWork do stolenWork[loc.id] = (toSteal, c_malloc(eltType, toSteal));
                              var destPtr = stolenWork[here.id][1];
                              targetSegment.transferElements(destPtr, toSteal, stolenWork.locale.id);
                              targetSegment.releaseStatus();

                              // We are done...
                              break;
                            }

                            // Backoff...
                            chpl_task_yield();
                          }
                        }
                      }
                    }

                    // It is our job now to distribute all stolen data to the same
                    // horizontal segment on our node. Acquire lock...
                    ref recvSegment = segments[segmentIdx];
                    while true {
                      if ((recvSegment.currentStatus == STATUS_UNLOCKED) && recvSegment.acquireWithStatus(STATUS_ADD)) then break;
                      chpl_task_yield();
                    }

                    // Add stolen elements to segment...
                    for (nStolen, stolenPtr) in stolenWork {
                      if (nStolen == 0) then continue;
                      recvSegment.addElementsPtr(stolenPtr, nStolen);
                      c_free(stolenPtr);

                      // Let parent know that the bag is not empty.
                      isEmpty.write(false);
                    }
                    recvSegment.releaseStatus();
                  }

                  loadBalanceResult.write(!isEmpty.read());
                  loadBalanceInProgress.write(false);

                  // At this point, if no work has been found, we will return empty...
                  if isEmpty.read() {
                    var default: eltType;
                    return (false, default);
                    } else {
                      // Otherwise, we try to get data like everyone else.
                      phase = REMOVE_SIMPLE;
                      break;
                    }
                  }
                }
              }

              // Backoff to maximum...
              chpl_task_yield();
            }
          }

          otherwise do halt("DistributedBag Internal Error: Invalid phase #", phase);
        }

        // Reset variables...
        idx = startIdx;
        iterations = 0;
        backoff = 0;
      }

      halt("DistributedBag Internal Error: DEADCODE.");
    }

    /*
      Retrieval operation that succeeds when one of the three successives case
      succeeds. In BEST CASE, the caller try to remove an element from its segment.
      In AVERAGE CASE, the caller try to steal another segment of its bag instance.
      In WORST CASE, the caller try to steal another segment of another bag instance.
      The operation fails if all cases failed.
    */
    proc remove(const threadId: int): (int, eltType)
    {
      var phase = REMOVE_STEAL_REQUEST;
      var locId: int = here.id;

      while true {
        select phase {
          /*
            STEAL REQUEST:
            We first check if there is a pending external steal request. If yes,
            we take the lead and perform a local steal (as usual), before sending
            the resulting buffer to the stealer.
          */
          when REMOVE_STEAL_REQUEST {

            // if segment 'threadId' detects an external stealing request, it takes
            // the lead, and indicates it to the other segments by setting 'false'
            /* if steal_request.compareAndSwap(true, false) {
              var default: eltType;

              const parentPid = parentHandle.pid;
              var stolenElts: list(eltType);

              // selection of the victim segments
              for idx in 0..#here.maxTaskPar {
                ref targetSegment = segments[idx];

                //var sharedElts: int = targetSegment.nElems_shared.read();
                // if the shared region contains enough elements to be stolen...
                if (2 <= targetSegment.nElems_shared.read()) {

                  for i in 0..#(targetSegment.nElems_shared.read()/2):int {
                    // attempt to steal an element
                    var (hasElem, elem): (bool, eltType) = targetSegment.steal();

                    // if the steal succeeds...
                    if hasElem {
                      stolenElts.insert(0, elem);
                    }
                  }

                }
                // otherwise, if the private region has elements, we request for a split shifting
                else if (targetSegment.nElems_private > 1) {
                  targetSegment.split_request.write(true);
                }
              } // for idx

              writeln("loc/thread ", here.id, " ", threadId, " prepares :", stolenElts.size);

              on Locales[stealer_locId.read()] {
                var targetBag = chpl_getPrivatizedCopy(parentHandle.type, parentPid).bag;

                // if the steal fails...
                if (stolenElts.size == 0) {
                  targetBag!.steal_status.write(false);
                }
                else {
                  ref targetSegment = targetBag!.segments[stealer_segId.read()];

                  for i in 0..#stolenElts.size {
                    targetSegment.addElement(stolenElts[i]);
                  }
                  targetBag!.steal_status.write(true);
//                  targetSegment.split_request.write(true);
                }

                // set to empty
                targetBag!.request_status$.reset();
              }

            } // if steal */

            phase = REMOVE_SIMPLE;
          }

          /*
            SIMPLE:
            We try to retrieve an element in segment 'threadId'. Retrieval is done
            at the tail of the segment's block. This try fails if the private region
            is empty.
          */
          when REMOVE_SIMPLE {

            ref segment = segments[threadId];

            // if the private region contains at least one element to be removed...
            if (segment.nElems_private >= 1) {
              // attempt to remove an element
              var (hasWork, elt): (bool, eltType) = segment.takeElement();

              if hasWork then return (REMOVE_SUCCESS, elt);
              /* if hasWork then return (1, elt);
              else return (-1, default); */
            }

            phase = REMOVE_LOCAL_STEAL;
          }

          /*
            LOCAL STEAL: intra-node work stealing
            It seems that segment 'threadId' is empty so we try to steal another one.
            The victim selection is set in the 'victim' iterator, and defaults to random.
            The work stealing fails when all segments don't satisfied the condition to be
            a victim, or when a shared region becomes empty due to a concurrent operation.
          */
          when REMOVE_LOCAL_STEAL {

            var default: eltType;
            var splitreq: bool = false;

            // fast exit if: (1) a segment of our bag instance is doing a global steal
            // (2) a global steal is performed on our segment (priority is given).
            // if globalStealInProgress.read() then return (REMOVE_FAST_EXIT, default);

            if globalStealInProgress.read() {
              return (REMOVE_FAST_EXIT, default);
            }

            segments[threadId].nSteal1 += 1;
            segments[threadId].timer1.start();

            // selection of the victim segment
            for idx in victim("thread", threadId, "rand", here.maxTaskPar) {
              ref targetSegment = segments[idx];

              if !targetSegment.globalSteal.read() {
                // if the shared region contains enough elements to be stolen...
                if (distributedBagWorkStealingMinElems <= targetSegment.nElems_shared.read()) {
                  // attempt to steal an element
                  var (hasElem, elem): (bool, eltType) = targetSegment.steal();

                  // if the steal succeeds, we return, otherwise we continue
                  if hasElem {
                    segments[threadId].timer1.stop();
                    segments[threadId].nSSteal1 += 1;
                    return (REMOVE_SUCCESS, elem);
                  }
                }
                // otherwise, if the private region has elements, we request for a split shifting
                else if (targetSegment.nElems_private > 1) {
                  splitreq = true;
                  targetSegment.split_request.write(true);
                }
              }
            }

            segments[threadId].timer1.stop();

            if splitreq then return (REMOVE_FAST_EXIT, default);

            phase = REMOVE_GLOBAL_STEAL;
          }

          /*
            GLOBAL STEAL: inter-node work stealing
            The caller fails to remove an element on its bag instance, so we try
            to steal another bag. The victim selection of the locale is set in the
            'victim' iterator, and the segments are then visited in a 'ring' fashion.
            The inter-node work stealing fails when all segments of all locales don't
            satisfied the condition to be a victim, or when a shared region becomes
            empty due to a concurrent operation.
          */
          when REMOVE_GLOBAL_STEAL {
            var default: eltType;
            //var (hasStolen, stolenElt): (bool, eltType) = (false, default);

            // fast exit for single-node execution
            if (numLocales == 1) then return (REMOVE_FAIL, default);

            // "Lock" the global steal operation
            if !globalStealInProgress.compareAndSwap(false, true) {
              return (REMOVE_FAST_EXIT, default);
            }

            /* const parentPid = parentHandle.pid;
            var timer, subtimer: Timer;
            var status: int = 0;
            //timer.start();

            // profiling
            writeln("loc/thread ", here.id, " ", threadId, " request a steal: ", segments.nElems);
            segments[threadId].nSteal2 += 1;
            segments[threadId].timer2.start();

            // selection of the victim locale
            for idx in victim("locale", here.id, "rand", 1) {
              on Locales[idx] {
                var targetBag = chpl_getPrivatizedCopy(parentHandle.type, parentPid).bag;

                if targetBag!.end_exploration.read() {
                  // if the target bag has detected the end of the exploration, we
                  // set the 'end_exploration' flag and break the stealing operation
                  // via 'status'.
                  end_exploration.write(true);
                  status = -1;
                }
                else {
                  // if the target bag has not detected the end of the exploration,
                  // we request a steal via the 'steal_request' flag. Then, we break
                  // the stealing operation.
                  targetBag!.stealer_locId.write(locId);
                  targetBag!.stealer_segId.write(threadId);
                  targetBag!.steal_request.write(true);
                  status = 1;
                }
              }
            }
            if (status == -1) {
              // if the end of the exploration is detected, we return.
              return (REMOVE_FAIL, default);
            }

            // wait until the steal request in accomplished by a thread.
            request_status$.writeEF(true);

            // profiling
            writeln("loc/thread ", here.id, " ", threadId, " is released: ", segments.nElems);

            // return according to the end status of the stealing operation.
            if steal_status.read() {
              globalStealInProgress.write(false);
              segments[threadId].nSSteal2 += 1;
              segments[threadId].timer2.stop();
              return (REMOVE_SUCCESS, segments[threadId].takeElement()[1]);
            }
            else {
              globalStealInProgress.write(false);
              segments[threadId].timer2.stop();
              return (REMOVE_FAIL, default);
            } */

            const parentPid = parentHandle.pid;
            var stolenElts: list(eltType);
            var timer, subtimer: Timer;

            //writeln("loc/thread ", here.id, " ", threadId, ", state of bag ", segments.nElems);

            segments[threadId].nSteal2 += 1;
            segments[threadId].timer2.start();

            timer.start();

            // selection of the victim locale
            for idx in victim("locale", here.id, "rand", 1) { //numLocales-1) {
              on Locales[idx] {
                var targetBag = chpl_getPrivatizedCopy(parentHandle.type, parentPid).bag;
                // selection of the victim segment
                for seg in victim("thread", threadId, "rand", here.maxTaskPar) { //0..#here.maxTaskPar {
                  ref targetSegment = targetBag!.segments[seg];

                  targetSegment.globalSteal.write(true);

                  //var sharedElts: int = targetSegment.nElems_shared.read();
                  // if the shared region contains enough elements to be stolen...
                  if (2 <= targetSegment.nElems_shared.read()) {
                    //for i in 0..#(targetSegment.nElems_shared.read()/2):int {
                      // attempt to steal an element
                      var (hasElem, elem): (bool, eltType) = targetSegment.steal();

                      subtimer.start();
                      // if the steal succeeds...
                      if hasElem {
                        stolenElts.insert(0, elem);
                      }
                      subtimer.stop();
                  //  }
                  }
                  // otherwise, if the private region has elements, we request for a split shifting
                  else if (targetSegment.nElems_private >= 2) {
                    targetSegment.split_request.write(true);
                  }

                  targetSegment.globalSteal.write(false);
                }
              }
            }

            // if the global steal fails...
            if (stolenElts.size == 0) {
              // "Unlock" the global steal operation
              globalStealInProgress.write(false);
              timer.stop();
              segments[threadId].timer2.stop();
              return (REMOVE_FAIL, default);
            }
            else {
              writeln(stolenElts.size);
              for elt in stolenElts do segments[threadId].addElement(elt);
              //segments[threadId].split.add((3*stolenElts.size/4):int);
              segments[threadId].nSSteal2 += 1;

              writeln("loc/thread ", here.id, " ", threadId, ", steals in ", timer.elapsed(TimeUnits.seconds));
              writeln("loc/thread ", here.id, " ", threadId, ", selection in ", subtimer.elapsed(TimeUnits.seconds));

              // "Unlock" the global steal operation
              globalStealInProgress.write(false);
              timer.stop();
              segments[threadId].timer2.stop();
              return (REMOVE_SUCCESS, segments[threadId].takeElement()[1]);
            }
          }

          otherwise do halt("DistributedBag Internal Error: Invalid phase #", phase);
        }
        chpl_task_yield();
      }

      halt("DistributedBag Internal Error: DEADCODE.");
    }
  } // end 'Bag' class

  /*
    A Segment is, in and of itself an unrolled linked list. We maintain one per core
    to ensure maximum parallelism.
  */
  record Segment
  {
    type eltType;

    var globalSteal: atomic bool = false;

    // Used as a test-and-test-and-set spinlock.
    var status: atomic uint;

    var block: unmanaged Block(eltType)?;

    // private variables
    var o_split: int;
    var o_allstolen: bool;
    var tail: int;

    // shared variables
    var split: atomic int;
    var head: atomic int;
    var allstolen: atomic bool;
    var split_request: atomic bool;
    var nElems_shared: atomic int; // number of elements in the shared space

    // for profiling
    var nSteal1: int;
    var nSSteal1: int;
    var nSteal2: int;
    var nSSteal2: int;

    var timer1, timer2: Timer;

    // locks (initially unlocked)
    var lock$: sync bool = true;
    var lock_n$: sync bool = true;

    /*
      Returns the size of the private region. This information is computed from the
      tail and split pointers, and since the block is implemented as a  circular
      array, two cases need to be distinguished.
    */
    // WARNING: We consider the common case only for the moment
    inline proc nElems_private
    {
      // common case
      if (tail >= o_split) {
        return tail - o_split;
      }
      // specific case where tail < o_split, due to the circular array
      else {
        return block!.cap - o_split + tail;
      }
    }

    inline proc nElems
    {
      return nElems_private + nElems_shared.read();
    }

    inline proc isEmpty
    {
      lock_n$.readFE();
      var n_shared = nElems_shared.read();
      var n_private = nElems_private;
      lock_n$.writeEF(true);
      return (n_shared + n_private) == 0;
    }

    // STATUS (acquireWithStatus)
    inline proc acquireWithStatus(newStatus)
    {
      return status.compareAndSwap(STATUS_UNLOCKED, newStatus);
    }

    // UNUSED. (acquire) Only needed in 'balance'
    //Set status with a test-and-test-and-set loop...
     inline proc acquire(newStatus)
    {
      while true {
        if ((currentStatus == STATUS_UNLOCKED) && acquireWithStatus(newStatus)) then break;
        chpl_task_yield();
      }
    }

    // STATUS (acquireIfNonEmpty) Only used in clear() and these() iterators
    // Set status with a test-and-test-and-set loop, but only while it is not empty...
    inline proc acquireIfNonEmpty(newStatus): bool
    {
      while !isEmpty {
        if ((currentStatus == STATUS_UNLOCKED) && acquireWithStatus(newStatus)) {
          if isEmpty {
            releaseStatus();
            return false;
          } else {
            return true;
          }
        }

        chpl_task_yield();
      }

      return false;
    }

    // STATUS (isUnlocked)
    inline proc isUnlocked
    {
      return status.read() == STATUS_UNLOCKED;
    }

    // STATUS (currentStatus)
    inline proc currentStatus
    {
      return status.read();
    }

    // STATUS (releaseStatus)
    inline proc releaseStatus()
    {
      status.write(STATUS_UNLOCKED);
    }

    /* inline proc transferElements(destPtr, n, locId = here.id)
    {
      var destOffset = 0;
      var srcOffset = 0;
      while (destOffset < n) {
        if ((block == nil) || isEmpty) {
          halt(here, ": DistributedBag Internal Error: Attempted transfer ", n, " elements to ", locId, " but failed... destOffset=", destOffset);
        }

        var len = block!.size;
        var need = n - destOffset;
        // If the amount in this block is greater than what is left to transfer, we
        // cannot begin transferring at the beginning, so we set our offset from the end.
        if (len > need) {
          srcOffset = len - need;
          block!.size = srcOffset;
          __primitive("chpl_comm_array_put", block!.elems[srcOffset], locId, destPtr[destOffset], need);
          destOffset += need;
        } else {
          srcOffset = 0;
          block!.size = 0;
          __primitive("chpl_comm_array_put", block!.elems[srcOffset], locId, destPtr[destOffset], len);
          destOffset += len;
        }
      }

      nElems.sub(n:int);
    } */

    // Derived from above.
    /* inline proc transferElements(destPtr, n, locId = here.id)
    {
      writeln("start transfer");
      writeln("head = ", head.read());
      writeln("split = ", split.read());
      writeln("tail = ", tail);
      writeln("n = ", n);
      writeln("block = ", block!.elems);
      writeln("destPtr = ", destPtr);
      __primitive("chpl_comm_array_put", block!.elems[head.read()], locId, destPtr[0], n);
      nElems_shared.sub(n);
      head.add(n);
      writeln("end transfer");
    } */

    // UNUSED (addElementsPtr) Only in balance() and old remove()
    /* proc addElementsPtr(ptr, n, locId = here.id)
    {
      var offset = 0;
      while (offset < n) {

        // Empty? Create a new one of initial size
        if (block == nil) {
          block = new unmanaged Block(eltType, distributedBagInitialBlockSize);
        }

        // Full? Create a new one double the previous size
         if block!.isFull {
          block!.next = new unmanaged Block(eltType, min(distributedBagMaxBlockSize, block!.cap * 2));
          block = block!.next;
        }

        var nLeft = n - offset;
        var nSpace = block!.cap - block!.size;
        var nFill = min(nLeft, nSpace);
        __primitive("chpl_comm_array_get", block!.elems[block!.size], locId, ptr[offset], nFill);
        block!.size += nFill;
        offset += nFill;
      }

      nElems.add(n:int);
    } */

    // Derived from the previous one.
    /* inline proc addElementsPtr(ptr, n, locId = here.id)
    {
      writeln("start addElts");
      __primitive("chpl_comm_array_get", block!.elems[nElems], locId, ptr[0], n);
      block!.tailIdx += n;
      tail += n;
      writeln("end addElts");
    } */

    // UNUSED (takeElements)
    /* inline proc takeElements(n, side: string)
    {
      var iterations = n:int;
      var arr: [{0..#n : int}] eltType;
      var arrIdx = 0;

      for 1..n : int {
        if isEmpty then halt("DistributedBag Internal Error: Attempted to take ", n, " elements when insufficient");
        if headBlock!.isEmpty then halt("DistributedBag Internal Error: Iterating over ", n, " elements with headBlock empty but nElems is ", nElems.read());

        arr[arrIdx] = headBlock.pop();
        arrIdx += 1;
        nElems.sub(1);

        // Fix list if we consumed last one...
        if headBlock!.isEmpty {
          var tmp = headBlock;
          headBlock = headBlock!.next;
          delete tmp;

          if (headBlock == nil) then tailBlock = nil;
        }
      }

      return arr;
    } */

    inline proc simCAS(A: atomic int, B: atomic int, expA: int, expB: int, desA: int, desB: int): bool
    {
      var casA, casB: bool;
      lock$.readFE(); // set locked (empty)
      casA = A.compareAndSwap(expA, desA);
      casB = B.compareAndSwap(expB, desB);
      if (casA && casB) {
        lock$.writeEF(true); // set unlocked (full)
        return true;
      }
      else {
        if casA then A.write(expA);
        if casB then B.write(expB);
        lock$.writeEF(true); // set unlocked (full)
        return false;
      }
      halt("DistributedBag Internal Error: DEADCODE");
    }

    /*
      Stealing operation, only executed by thieves.
    */
    inline proc steal(): (bool, eltType)
    {
      var default: eltType;

      // if the shared region becomes empty due to a concurrent operation...
      if (nElems_shared.read() == 0) then return (false, default);

      // Fast exit
      /* if allstolen.read() then return (false, default); */

      lock$.readFE(); // set locked (empty)
      var (h, s): (int, int) = (head.read(), split.read());
      lock$.writeEF(true); // set unlocked (full)

      // if there are elements to steal...
      if (h < s) {
        // if we successfully moved the pointers...
        if simCAS(head, split, h, s, h+1, s) {
          lock_n$.readFE();
          var elem = block!.popHead();

          nElems_shared.sub(1);
          lock_n$.writeEF(true);

          return (true, elem);
        }
        else {
          return (false, default);
        }
      }

      // set the split request, if not already set...
      if !split_request.read() then split_request.write(true);

      return (false, default);
    }

    /* // We can take element at the tail or head block, according to the 'side' argument.
    inline proc takeElement(side: string)
    {
      // If the segment is empty
      if isEmpty {
        var default: eltType;
        return (false, default);
      }

      if block!.isEmpty then halt("DistributedBag Internal Error: Iterating over 1 element with headBlock empty but nElems is ", nElems.read());

      if (side == 't') { // remove at the 't'ail
        var elem = block!.popTail();
        nElems.sub(1);

        if block!.isEmpty { // if block is now empty
          delete block;
          block = nil;
        }

        return (true, elem);
      }
      else if (side == 'h') { // remove at the 'h'ead
        var elem = block!.popHead();
        nElems.sub(1);

        if block!.isEmpty { // if block is now empty
          delete block;
          block = nil;
        }

        return (true, elem);
      }
      else halt("DistributedBag Internal Error: Wrong 'side' choice in takeElement().");
    } */

    /*
      Retrieve operation, only executed by the segment's owner.
    */
    inline proc takeElement(): (bool, eltType)
    {

      // if the segment is empty...
      if (nElems_private == 0) {
        var default: eltType;
        return (false, default);
      }

      /* if o_allstolen then {
        var elem = block!.popTail();
        nElems_private.sub(1);

        return (true, elem);
      } */

      // if the private region is empty...
      if (nElems_private == 0) { //(o_split == tail) {
        // if we successfully shring the shared region...
        if shrink_shared() {
          var elem = block!.popTail();
          tail -= 1; //?

          return (true, elem);
        }
      }

      // if the private region is not empty...
      var elem = block!.popTail();
      tail -= 1;

      // if there is a split request...
      if split_request.read() then grow_shared();

      return (true, elem);
    }

    /* // Insertion operation equivalent to pushTail
    inline proc addElement(elt: eltType)
    {
      // 'block' empty ? (= empty segment) Create a new one of initial size
      if (block == nil) {
        block = new unmanaged Block(eltType, distributedBagInitialBlockSize);
      }

      // 'block' full ? Create a new one double the previous size
      if block!.isFull {
        halt("DistributedBag Internal Error: 'block' full.");
      }

      block!.pushTail(elt);
      nElems.add(1);
    } */

    /*
      Insertion operation, only executed by the segment's owner.
    */
    inline proc addElement(elt: eltType)
    {
      // if the block is not already initialized...
      if (block == nil) then block = new unmanaged Block(eltType, distributedBagInitialBlockSize);

      // we add the element at the tail
      block!.pushTail(elt);
      tail += 1;

      // if there is a split request...
      if split_request.read() then grow_shared();

      /* if o_allstolen {
        lock$.readFE(); // block until its full and set locked (empty)
        head.write(tail - 1);
        split.write(tail);
        lock$.writeEF(true); // set unlocked (full)
        o_split = tail;
        allstolen.write(false);
        o_allstolen = false;
        if split_request.read() then split_request.write(false);
      }
      else if split_request.read() then grow_shared(); */
    }

    /*
      Grow operation that increases the shared space of the deque.
    */
    inline proc grow_shared(): void
    {
      // fast exit
      if (nElems_private <= 1) then return;

      // compute the new split position
      var new_split: int = ((o_split + tail + 1) / 2): int;
      lock$.readFE(); // block until its full and set locked (empty)
      split.write(new_split);
      lock$.writeEF(true); // set unlocked (full)

      // updates the counters
      lock_n$.readFE();
      nElems_shared.add(new_split - o_split);
      lock_n$.writeEF(true);

      o_split = new_split;

      // reset split_request
      split_request.write(false);
    }

    /*
      Shrink operation that reduces the shared space of the deque.
    */
    inline proc shrink_shared(): bool
    {
      // fast exit
      if (nElems_shared.read() <= 1) then return false;

      lock$.readFE(); // block until its full and set locked (empty)
      var (h, s): (int, int) = (head.read(), split.read()); // o_split ?
      lock$.writeEF(true); // set unlocked (full)
      if (h != s) {
        var new_split: int = ((h + s) / 2): int;
        lock$.readFE(); // block until its full and set locked (empty)
        split.write(new_split);
        lock$.writeEF(true); // set unlocked (full)
        lock_n$.readFE();
        nElems_shared.sub(new_split - o_split);
        lock_n$.writeEF(true);
        o_split = new_split;
        // ADD FENCE
        atomicFence();
        h = head.read();
        if (h != s) {
          if (h > new_split) {
            new_split = ((h + s) / 2): int;
            lock$.readFE(); // block until its full and set locked (empty)
            split.write(new_split);
            lock$.writeEF(true); // set unlocked (full)
            lock_n$.readFE();
            nElems_shared.sub(new_split - o_split);
            lock_n$.writeEF(true);
            o_split = new_split;
          }
          return false;
        }
      }
      allstolen.write(true);
      o_allstolen = true;
      return true;
    }

    // UNUSED (addElements) Only in balance() and old remove()
    /* inline proc addElements(elts)
    {
      for elt in elts do addElement(elt);
    } */

  } // end Segment record

  /*
    A segment block is an unrolled linked list node that holds a contiguous buffer
    of memory. Each segment block size *should* be a power of two, as we increase the
    size of each subsequent unroll block by twice the size. This is so that stealing
    work is faster in that majority of elements are confined to one area.
    It should be noted that the block itself is not parallel-safe, and access must be
    synchronized.
  */
  class Block
  {
    type eltType;
    var elems: c_ptr(eltType); // contiguous memory containing all elements
    // TODO: test with elems: cap * eltType

    var cap: int; // capacity of the block
    /* var size: int; // number of occupied elements in the block */
    var headIdx: int; // index of the head element
    var tailIdx: int; // index of the tail element

    /* inline proc isEmpty
    {
      return headIdx == tailIdx;
      return size == 0;
    } */

    /* inline proc isFull
    {
      return size == cap;
    } */

    // ISSUE: Cannot insert Chapel array due to "c_malloc".
    proc init(type eltType, capacity)
    {
      if (capacity == 0) then halt("DistributedBag Internal Error: Capacity is 0.");
      this.eltType = eltType;
      this.elems = c_malloc(eltType, capacity);
      this.cap = capacity;
      // the following is unnecessary I think
      /* this.size = 0; */
      this.headIdx = 0;
      this.tailIdx = 0;
    }

    // UNUSED (init) I think
    /* proc init(type eltType, ptr, capacity)
    {
      this.eltType = eltType;
      this.elems = ptr;
      this.cap = capacity;
      this.size = cap;
    } */

    proc deinit()
    {
      c_free(elems);
    }

    inline proc pushTail(elt: eltType): void
    {
      // security check
      if (elems == nil) then halt("DistributedBag Internal Error in 'pushTail': 'elems' is nil.");
      /* if isFull then halt("DistributedBag Internal Error in 'pushTail': Block is Full."); */

      elems[tailIdx] = elt;
      tailIdx +=1;
      if (tailIdx >= cap) then tailIdx = 0;
      /* size += 1; */

      return;
    }

    // UNUSED (pushHead)
    /* inline proc pushHead(elt: eltType): void
    {
      if (elems == nil) then halt("DistributedBag Internal Error in 'pushHead': 'elems' is nil.");
      if isFull then halt("DistributedBag Internal Error in 'pushHead': Block is Full.");

      headIdx -= 1;
      if (headIdx == -1) then headIdx = cap - 1;
      elems[headIdx] = elt;
      size += 1;

      return;
    } */

    inline proc popTail(): eltType
    {
      // security check
      if (elems == nil) then halt("DistributedBag Internal Error in 'popTail': 'elems' is nil.");
      /* if isEmpty then halt("DistributedBag Internal Error in 'popTail': Block is Empty."); */

      tailIdx -= 1;
      if (tailIdx < 0) then tailIdx = cap - 1;
      /* size -= 1; */

      return elems[tailIdx];
    }

    inline proc popHead(): eltType
    {
      // security check
      if (elems == nil) then halt("DistributedBag Internal Error in 'popHead': 'elems' is nil.");
      /* if isEmpty then halt("DistributedBag Internal Error in 'popHead': Block is Empty."); */

      var elt = elems[headIdx];
      headIdx += 1;
      if (headIdx >= cap) then headIdx = 0;
      //size -= 1;

      return elt;
    }
  } // end 'Block' class

} // end module
