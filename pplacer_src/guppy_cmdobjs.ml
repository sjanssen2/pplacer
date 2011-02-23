(*
 * This is for the hierarchy of common command objects.
 *)

open Subcommand

class out_prefix_cmd () =
object
  val out_prefix = flag "-o"
    (Needs_argument ("out-prefix", "Set the prefix to write to. Required."))
  method specl = [ string_flag out_prefix; ]
end

class out_dir_cmd () =
object
  val out_dir = flag "--out-dir"
    (Plain (".", "Specify the directory to write place files to."))
  method specl = [ string_flag out_dir; ]
end

class mass_cmd () =
object
  val use_pp = flag "--pp"
    (Plain (false, "Use posterior probability for the weight."))
  val weighted = flag "--unweighted"
    (Plain (true, "Treat every placement as a point mass concentrated on the highest-weight placement."))
  val transform = flag "--transform"
    (Plain ("", Mokaphy_common.transform_help))
  method specl = [
    toggle_flag use_pp;
    toggle_flag weighted;
    string_flag transform;
  ]
end

(* is this dependency goiung to be scary *)
class refpkg_cmd () =
object
  val refpkg_path = flag "-c"
    (Needs_argument ("reference package path", "Reference package path"))
  method specl = [ string_flag refpkg_path; ]

  method private get_rpo_tree pr =
    let alt_tree = Decor_gtree.of_newick_gtree pr.Placerun.ref_tree in
    match Refpkg.refpkgo_of_path (fv refpkg_path) with
      | None -> (None, alt_tree)
      | Some rp ->
        Refpkg.check_tree_identical
          ~epsilon:1e-5
          (pr.Placerun.name^" reference tree")
          (Placerun.get_ref_tree pr)
          rp;
        if Refpkg.tax_equipped rp then (Some rp, Refpkg.get_tax_ref_tree rp)
        else (None, alt_tree)
end

class viz_cmd () =
object
  val white_bg = flag "--whitebg"
    (Plain (false, "Make colors appropriate for a white background."))
  val min_fat_bl = flag "--min-fat"
    (Formatted (1e-2, "The minimum branch length for fattened edges (to increase their visibility). To turn off set to 0. Default: %g"))
  val total_width = flag "--total-width"
    (Formatted (400., "Set the total number of pixels for all of the mass. Default: %g"))
  val unit_width = flag "--unit-width"
    (Plain (0., "Set the number of pixels for a single placement (will override total-width if set)."))
  method specl = [
    toggle_flag white_bg;
    float_flag min_fat_bl;
    float_flag total_width;
    float_flag unit_width;
  ]
end

class outfile_cmd () =
object
  val out_fname = flag "-o"
    (Plain ("-", "Set the filename to write to. Otherwise write to stdout."))
  method specl = [ string_flag out_fname; ]

  method private out_channel =
    match fv out_fname with
      | "-" -> stdout
      | s -> open_out s
end

let place_file_rex = Str.regexp ".*\\.place"
module SM = MapsSets.StringMap

(* *** accessing placefiles *** *)
(* our strategy is to load the placefiles in to memory when we need them, but if
  * they are already in memory, then we use them *)
let placerun_map = ref SM.empty
let placerun_by_name fname =
  if not (Str.string_match place_file_rex fname 0) then
    failwith ("Place files must end with .place suffix, unlike: "^fname);
  if SM.mem fname !placerun_map then
    SM.find fname !placerun_map
  else begin
    let pr = Placerun_io.filtered_of_file fname in
    if 0 = Placerun.n_pqueries pr then failwith (fname^" has no placements!");
    placerun_map := SM.add fname pr !placerun_map;
    pr
  end

class virtual placefile_cmd () =
object (self)
  inherit outfile_cmd ()

  method virtual private placefile_action: 'a Placerun.placerun list -> out_channel -> unit
  method action fnamel =
    let prl = List.map placerun_by_name fnamel
    and ch = self#out_channel in
    self#placefile_action prl ch
end
