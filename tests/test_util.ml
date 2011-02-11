(* Assume the test runner is running in the project root. We can't do much
   better than this. *)
let tests_dir = "./tests/"

let pres_of_dir which =
  let files = Common_base.get_dir_contents
    ~pred:(fun name -> Filename.check_suffix name "place")
    (tests_dir ^ "mokaphy/data/" ^ which) in
  let tbl = Hashtbl.create 10 in
  List.iter(fun f ->
    let pr = Placerun_io.of_file f in
    let pre = Mass_map.Pre.of_placerun Mass_map.Weighted Placement.ml_ratio pr in
    Hashtbl.add tbl pr.Placerun.name (pr, pre)
  ) files;
  tbl
;;

let fabs x = if x > 0.0 then x else -. x;;

let approximately_equal ?(epsilon = 1e-5) f1 f2 = fabs (f1 -. f2) < epsilon;;