/*
  This test checks the 'DistBag_DFS.writeThis()' method.
*/

use DistributedBag_DFS;

var bag = new DistBag_DFS(int);

// Check for multiple values inserted concurrently.
forall taskId in 0..#here.maxTaskPar do
  bag.add(taskId, taskId);

writeln(bag);

// Check for empty bag.
bag.clear();

writeln(bag);

// Check for multiple values inserted concurrently on different locales.
coforall loc in Locales do on loc {
  forall taskId in 0..#here.maxTaskPar do
    bag.add(taskId, taskId);
}

writeln(bag);
