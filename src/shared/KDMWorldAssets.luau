-- Three static primary boards; the remaining art stays reserved.
return table.freeze({
 Boards = table.freeze({KDM_BOARD1="70653579286902", KDM_BOARD2="107343114207145",
  KDM_BOARD3="139408907905534", KDM_BOARD4="71781787821289",
  KDM_BOARD5="129223906642764", KDM_BOARD6="83035647106412"}),
 Primary = table.freeze({Hero="KDM_BOARD6", Garage="KDM_BOARD4", Tracks="KDM_BOARD2"}),
 Reserve = table.freeze({"KDM_BOARD1","KDM_BOARD3","KDM_BOARD5"}),
})
