open Fam_batteries
open MapsSets
open Subcommand
open Guppy_cmdobjs

type result =
  {
    distance : float;
    p_value : float option;
  }

let get_distance r = r.distance
let get_p_value r = match r.p_value with
  | Some p -> p
  | None -> failwith "no p-value!"

let make_shuffled_pres transform n_shuffles pre1 pre2 =
  let pre_arr = Array.of_list (pre1 @ pre2)
  and n1 = List.length pre1
  and n2 = List.length pre2
  in
  let pquery_sub start len =
    Mass_map.Pre.normalize_mass transform
      (Array.to_list (Array.sub pre_arr start len))
  in
  ListFuns.init
    n_shuffles
    (fun _ ->
      Mokaphy_base.shuffle pre_arr;
      (pquery_sub 0 n1, pquery_sub n1 n2))

let pair_core transform p n_samples t pre1 pre2 =
  let calc_dist = Kr_distance.scaled_dist_of_pres transform p t in
  let original_dist = calc_dist pre1 pre2 in
  {
    distance = original_dist;
    p_value =
      if 0 < n_samples then begin
        let shuffled_dists =
          List.map
            (fun (spre1,spre2) -> calc_dist spre1 spre2)
            (make_shuffled_pres transform n_samples pre1 pre2)
        in
        Some
          (Mokaphy_base.list_onesided_pvalue
            shuffled_dists
            original_dist)
      end
      else None;
  }


(* core
 * run pair_core for each unique pair
 *)
class cmd () =
object (self)
  inherit subcommand () as super
  inherit mass_cmd () as super_mass
  inherit refpkg_cmd () as super_refpkg
  inherit placefile_cmd () as super_placefile

  val p_exp = flag "--exp"
    (Plain (1., "The exponent for the integration, i.e. the value of p in Z_p."))
  val list_output = flag "--list-out"
    (Plain (false, "Output the KR results as a list rather than a matrix."))
  val density = flag "--density"
    (Plain (false, "write out a shuffle density data file for each pair."))
  val n_samples = flag "-s"
    (Formatted (1, "Set how many samples to use for significance calculation (0 means \
        calculate distance only). Default is %d."))
  val seed = flag "--seed"
    (Formatted (1, "Set the random seed, an integer > 0. Default is %d."))
  val verbose = flag "--verbose"
    (Plain (false, "Verbose running."))

  method specl =
    super_mass#specl
    @ super_refpkg#specl
    @ super_placefile#specl
    @ [
      string_flag out_fname;
      float_flag p_exp;
      toggle_flag list_output;
      toggle_flag density;
      int_flag n_samples;
      int_flag seed;
      toggle_flag verbose;
    ]

  method desc = ""
  method usage = ""

  method private placefile_action prl ch =
    if List.length prl < 2 then
      invalid_arg "can't do KR with fewer than two place files";
    let n_samples = fv n_samples
    and is_weighted = fv weighted
    and use_pp = fv use_pp
    and pra = Array.of_list prl
    and p = fv p_exp
    and transform = Mass_map.transform_of_str (fv transform)
    and tax_refpkgo = match !(refpkg_path.value) with
      | None -> None
      | Some path ->
        let rp = Refpkg.of_path path in
        if Refpkg.tax_equipped rp then Some rp
        else None
    in
    (* below is for make_shuffled_pres *)
    Random.init (fv seed);
    (* in the next section, pre_f is a function which takes a pr and makes a pre,
     * and t is a gtree *)
    let uptri_of_t_pre_f (t, pre_f) =
      let prea = Array.map pre_f pra in
      Uptri.init
        (Array.length prea)
        (fun i j ->
          let context =
            Printf.sprintf "comparing %s with %s"
              (Placerun.get_name pra.(i)) (Placerun.get_name pra.(j))
          in
          try pair_core transform p n_samples t prea.(i) prea.(j) with
          | Kr_distance.Invalid_place_loc a ->
              invalid_arg
              (Printf.sprintf
                 "%g is not a valid placement location when %s" a context)
          | Kr_distance.Total_kr_not_zero tkr ->
              failwith
                 ("total kr_vect not zero for "^context^": "^
                    (string_of_float tkr)))
    (* here we make one of these pairs from a function which tells us how to
     * assign a branch length to a tax rank *)
    and t_pre_f_of_bl_of_rank rp bl_of_rank =
      let (taxt, ti_imap) = Tax_gtree.of_refpkg_gen bl_of_rank rp in
      (Decor_gtree.to_newick_gtree taxt,
      Mokaphy_common.make_tax_pre taxt ~is_weighted ~use_pp ti_imap)
    in
    (* here we make a list of uptris, which are to get printed *)
    let uptris =
      List.map
        uptri_of_t_pre_f
        ([Mokaphy_common.list_get_same_tree prl,
        Mokaphy_common.pre_of_pr ~is_weighted ~use_pp] @
        (match tax_refpkgo with
        | None -> []
        | Some rp ->
            List.map (t_pre_f_of_bl_of_rank rp)
                     [Tax_gtree.unit_bl; Tax_gtree.inverse]))
    (* here are a list of function names to go with those uptris *)
    and fun_names =
      List.map
        (fun s -> Printf.sprintf "%s%g" s p)
        (["Z_"] @
        (match tax_refpkgo with
        | Some _ -> ["unit_tax_Z_"; "inv_tax_Z_"]
        | None -> []))
    (* the names of the placeruns *)
    and names = Array.map Placerun.get_name pra
    and print_pvalues = n_samples > 0
    and neighborly f l = List.flatten (List.map f l)
    in
    Mokaphy_common.write_uptril
      (fv list_output)
      names
      (if print_pvalues then neighborly (fun s -> [s;s^"_p_value"]) fun_names
      else fun_names)
      (if print_pvalues then
        neighborly (fun u -> [Uptri.map get_distance u; Uptri.map get_p_value u]) uptris
      else (List.map (Uptri.map get_distance) uptris))
      ch
end
