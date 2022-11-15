#include <iostream>
#include <time.h>

#include <prmu_decompose.h>
#include <binary_decompose.h>
#include <tree.h>
#include <shared_pool.h>

int
main(int argc, char ** argv)
{
    int SIZE = 8;

    // enumerate permutation
    {
        DecomposePerm decompose;
        PrunePerm_geq prune;
        Tree<PermutationSubproblem> tr(decompose,prune);

        std::unique_ptr<PermutationSubproblem> root = std::make_unique<PermutationSubproblem>(SIZE);

        struct timespec t1, t2;
        clock_gettime(CLOCK_MONOTONIC, &t1);

        tr.explore_n(root,1);

        clock_gettime(CLOCK_MONOTONIC, &t2);
        std::cout << "time\t" << (t2.tv_sec - t1.tv_sec) + (t2.tv_nsec - t1.tv_nsec) / 1e9 << "\n";
    }

    // enumerate binary
    {
        DecomposeBinary decompose;
        PruneBinary_geq prune;
        Tree<BinarySubproblem> tr(decompose,prune);

        std::unique_ptr<BinarySubproblem> root = std::make_unique<BinarySubproblem>(SIZE);

        struct timespec t1, t2;
        clock_gettime(CLOCK_MONOTONIC, &t1);

        tr.explore(root);

        clock_gettime(CLOCK_MONOTONIC, &t2);
        std::cout << "time\t" << (t2.tv_sec - t1.tv_sec) + (t2.tv_nsec - t1.tv_nsec) / 1e9 << "\n";
    }


    {
        SharedPool<PermutationSubproblem> p;
        DecomposePerm decompose;

        std::unique_ptr<PermutationSubproblem> root = std::make_unique<PermutationSubproblem>(SIZE);
        p.insert(root);

        int count_leaves = 0;
        struct timespec t1, t2;
        clock_gettime(CLOCK_MONOTONIC, &t1);

        #pragma omp parallel
        #pragma omp single nowait
        {
            for(int i=0;i<omp_get_num_threads();i++){
                #pragma omp task shared(decompose,p,count_leaves)
                {
                    while(p.size() > 0){
                        std::unique_ptr<PermutationSubproblem> n;
                        n = p.take();
                        if(n){
                            if(n->is_leaf()){
                                #pragma omp critical
                                {
                                    ++count_leaves;
                                    // std::cout<<p.size()<<"\t"<<count_leaves<<"\n";
                                }
                                p.nnodes_decr_one();
                            }else{
                                std::vector<std::unique_ptr<PermutationSubproblem>> ns = decompose(*n);
                                p.insert(std::move(ns));
                                p.nnodes_decr_one();
                            }
                        }
                    }
                }
            }
            #pragma omp taskwait
            std::cout<<"leaves :"<<count_leaves<<"\n";
        }

        clock_gettime(CLOCK_MONOTONIC, &t2);
        std::cout << "time\t" << (t2.tv_sec - t1.tv_sec) + (t2.tv_nsec - t1.tv_nsec) / 1e9 << "\n";
    }
} // main
