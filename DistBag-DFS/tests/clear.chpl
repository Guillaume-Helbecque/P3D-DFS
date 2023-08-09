/*
  This test checks the 'DistBag_DFS.clear()' method.
*/

use DistributedBag_DFS;

var bag = new DistBag_DFS(int);

// Insert multiple values concurrently on different locales.
coforall locId in 0..#numLocales do on Locales[locId] {
  coforall taskId in 0..#here.maxTaskPar {
    bag.add(taskId, taskId);
  }
}

writeln(bag);
bag.clear();
writeln(bag);
