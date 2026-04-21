#!/usr/bin/env bash

# QAPLIB optimal solutions are taken from:
#     https://qaplib.mgi.polymtl.ca/#BO

declare -A instances=(
  # ========== QAPLIB ==========
  # R.E. Burkard and J. Offermann
  ["bur26a"]=5426670
  ["bur26b"]=3817852
  ["bur26c"]=5426795
  ["bur26d"]=3821225
  ["bur26e"]=5386879
  ["bur26f"]=3782044
  ["bur26g"]=10117172
  ["bur26h"]=7098658
  # N. Christofides and E. Benavent
  ["chr12a"]=9552
  ["chr12b"]=9742
  ["chr12c"]=11156
  ["chr15a"]=9896
  ["chr15b"]=7990
  ["chr15c"]=9504
  ["chr18a"]=11098
  ["chr18b"]=1534
  ["chr20a"]=2192
  ["chr20b"]=2298
  ["chr20c"]=14142
  ["chr22a"]=6156
  ["chr22b"]=6194
  ["chr25a"]=3796
  # A.N. Elshafei
  ["els19"]=17212548
  # B. Eschermann and H.J. Wunderlich
  ["esc16a"]=68
  ["esc16b"]=292
  ["esc16c"]=160
  ["esc16d"]=16
  ["esc16e"]=28
  ["esc16f"]=0
  ["esc16g"]=26
  ["esc16h"]=996
  ["esc16i"]=14
  ["esc16j"]=8
  ["esc32a"]=130
  ["esc32b"]=168
  ["esc32c"]=642
  ["esc32d"]=200
  ["esc32e"]=2
  ["esc32g"]=6
  ["esc32h"]=438
  ["esc64a"]=116
  ["esc128"]=64
  # S.W. Hadley, F. Rendl and H. Wolkowicz
  ["had12"]=1652
  ["had14"]=2724
  ["had16"]=3720
  ["had18"]=5358
  ["had20"]=6922
  # J. Krarup and P.M. Pruzan
  ["kra30a"]=88900
  ["kra30b"]=91420
  ["kra32"]=88700
  # Y. Li and P.M. Pardalos
  ["lipa20a"]=3683
  ["lipa20b"]=27076
  ["lipa30a"]=13178
  ["lipa30b"]=151426
  ["lipa40a"]=31538
  ["lipa40b"]=476581
  ["lipa50a"]=62093
  ["lipa50b"]=1210244
  ["lipa60a"]=107218
  ["lipa60b"]=2520135
  ["lipa70a"]=169755
  ["lipa70b"]=4603200
  ["lipa80a"]=253195
  ["lipa80b"]=7763962
  ["lipa90a"]=360630
  ["lipa90b"]=12490441
  # C.E. Nugent, T.E. Vollmann and J. Ruml
  ["nug12"]=578
  ["nug14"]=1014
  ["nug15"]=1150
  ["nug16a"]=1610
  ["nug16b"]=1240
  ["nug17"]=1732
  ["nug18"]=1930
  ["nug20"]=2570
  ["nug21"]=2438
  ["nug22"]=3596
  ["nug24"]=3488
  ["nug25"]=3744
  ["nug27"]=5234
  ["nug28"]=5166
  ["nug30"]=6124
  # C. Roucairol
  ["rou12"]=235528
  ["rou15"]=354210
  ["rou30"]=725522
  # M. Scriabin and R.C. Vergin
  ["scr12"]=31410
  ["scr15"]=51140
  ["scr20"]=110030
  # L. Steinberg
  ["ste36a"]=9526
  ["ste36b"]=15852
  ["ste36c"]=8239110
  # E.D. Taillard
  ["tai12a"]=224416
  ["tai12b"]=39464925
  ["tai15a"]=388214
  ["tai15b"]=51765268
  ["tai17a"]=491812
  ["tai20a"]=703482
  ["tai20b"]=122455319
  ["tai25a"]=1167256
  ["tai25b"]=344355646
  ["tai30b"]=637117113
  # U.W. Thonemann and A. Bölte
  ["tho30"]=149936
  # ===== QUBIT ALLOCATION =====
  ["10_qft,16_melbourne"]=240
  ["10_sqn,16_melbourne"]=6140
  ["10_sym9,16_melbourne"]=13904
  ["11_sym9,16_melbourne"]=23936
  ["11_wim,16_melbourne"]=480
  ["11_z4,16_melbourne"]=2140
  ["12_cycle10,16_melbourne"]=4688
  ["12_rd84,16_melbourne"]=9864
  ["12_sym9,16_melbourne"]=196
  ["13_dist,16_melbourne"]=31682
  ["13_radd,16_melbourne"]=2484
  ["13_root,16_melbourne"]=13514
  ["14_clip,16_melbourne"]=33412
  ["14_cm42a,16_melbourne"]=836
  ["14_cm85a,16_melbourne"]=10678
  ["15_co14,16_melbourne"]=10824
  ["15_misex1,16_melbourne"]=3188
  ["15_sqrt7,16_melbourne"]=3072
  ["16_inc,16_melbourne"]=8318
  ["16_ising,16_melbourne"]=0
  ["16_mlp4,16_melbourne"]=21408
)
