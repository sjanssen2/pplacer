(* pplacer v0.2. Copyright (C) 2009  Frederick A Matsen.
 * This file is part of pplacer. pplacer is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. pplacer is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with pplacer.  If not, see <http://www.gnu.org/licenses/>.
*)

open Fam_batteries
open MapsSets
open Prefs

let version_str = "v0.2"

let prefs = 
  { 
    (* basics *)
    tree_fname = ref "";
    ref_align_fname = ref "";
    stats_fname = ref "";
    (* tree calc *)
    start_pend = ref 0.5;
    max_pend = ref 2.;
    tolerance = ref 0.01;
    calc_pp = ref false;
    uniform_prior = ref false;
    pp_rel_err = ref 0.01;
    (* model *)
    emperical_freqs = ref true;
    model_name = ref "LG";
    gamma_n_cat = ref 1;
    gamma_alpha = ref 1.;
    (* reading and writing *)
    verb_level = ref 1;
    write_masked = ref false;
    ratio_cutoff = ref 0.05;
    only_write_best = ref false
  }

let bifurcation_warning = 
  "Warning: pplacer results make the most sense when the \
  given tree is multifurcating at the root. See manual for details."

(* these are the args that we re-parse after parsing the phyml stat file *)
let model_name_opt = "-m", Arg.Set_string prefs.model_name,
  "Set the protein subs model. Options are LG (default) or WAG."
and gamma_n_cat_opt = "--gammaCats", Arg.Set_int prefs.gamma_n_cat,
 "Specify the number of categories for a discrete gamma model. (Default is \
 one, i.e. no gamma rate variation.)"
and gamma_alpha_opt = "--gammaAlpha", Arg.Set_float prefs.gamma_alpha,
 "Specify the shape parameter for a discrete gamma model."
let reparseable_opts = [model_name_opt; gamma_n_cat_opt; gamma_alpha_opt]

let parse_args () =
  let files  = ref [] in
  let t = "-t", Arg.Set_string prefs.tree_fname,
   "Specify the reference tree filename."
  and r = "-r", Arg.Set_string prefs.ref_align_fname,
   "Specify the reference alignment filename."
  and v = "-v", Arg.Set_int prefs.verb_level,
   "Set verbosity level. 0 is silent, and 2 is quite a lot."
  and p = "-p", Arg.Set prefs.calc_pp,
   "Calculate posterior probabilities."
  and c = "-c", Arg.Set_float prefs.ratio_cutoff,
  (Printf.sprintf
   "Specify the ratio cutoff for PP calculation and recording in the .place \
   file. Default is %g."
   !(prefs.ratio_cutoff))
  and b = "-b", Arg.Set prefs.only_write_best,
   "Only record the best PP and ML placements in the .place file, and do so \ 
   for every fragment."
  and s = "-s", Arg.Set_string prefs.stats_fname,
   "Supply a phyml stats.txt file which determines the model parameters. \
   Note that the information in this file can be overriden by specifying \
   things on the command line."
  and max_pend_opt = "--maxPend", Arg.Set_float prefs.max_pend,
   "Set the maximum pendant branch length for the ML and Bayes calculations."
  and tolerance_opt = "--mlTolerance", Arg.Set_float prefs.tolerance,
   "Specify the tolerance for the branch length maximization."
  and rel_err_opt = "--ppRelErr", Arg.Set_float prefs.pp_rel_err,
   "Specify the relative error for the posterior probability calculation."
  and model_freqs = "--modelFreqs", Arg.Clear prefs.emperical_freqs,
   "Use protein frequencies counted from the chosen model rather than counts \
   from the reference alignment."
  and unif_prior_opt = "--uniformPrior", Arg.Set prefs.uniform_prior,
   "Use a uniform prior rather than exponential in the posterior probability \
   calculation."
  and write_masked_opt = "--writeMasked", Arg.Set prefs.write_masked,
   "Write out the reference alignment with the query sequence, masked to the \
   region without gaps in the query."
  in
  let usage =
    "pplacer "^version_str^"\npplacer [options] -t ref_tree -r ref_align frags.fasta\n"
  and anon_arg arg =
    files := arg :: !files in
  let opts = 
    [t; r; v; p; c; b; s; max_pend_opt; tolerance_opt; rel_err_opt;
    model_freqs; unif_prior_opt; write_masked_opt] @ reparseable_opts in
  Arg.parse opts anon_arg usage;
  List.rev !files
     
    (* note return code of 0 is OK *)
let () =
  (* Gsl_error.init(); the ocamlgsl error handler slows things by 30% *)
  if not !Sys.interactive then begin
    print_endline "Running pplacer analysis...";
    let files = parse_args () in if files = [] then exit 0;
    (* load ref tree and alignment *)
    let ref_tree = match tree_fname prefs with
    | s when s = "" -> failwith "please specify a reference tree";
    | s -> Stree_io.of_newick_file s
    and ref_align = match ref_align_fname prefs with
    | s when s = "" -> failwith "please specify a reference alignment"
    | s -> Alignment.uppercase (Alignment.read_align s)
    in
    if (verb_level prefs) > 0 && 
       not (Stree.multifurcating_at_root ref_tree.Stree.tree) then
         print_endline bifurcation_warning;
    if (verb_level prefs) > 1 then begin
      print_endline "found in reference alignment: ";
      Array.iter (
        fun (name,_) -> print_endline ("\t'"^name^"'")
      ) ref_align
    end;
    (* parse the phyml/raxml stat file if it exists and build model. we want the
     * command line arguments to override the settings in the stat file, so we
     * first parse things according to that file, then rerun the Arg.parser for
     * certain settings. *)
    let opt_freqs_transitions = match stats_fname prefs with
    | s when s = "" -> None
    | _ -> Parse_stats.parse_stats prefs
    in
    (* now we re-parse the arguments to override if they are set *)
    Arg.parse reparseable_opts (fun _ -> ()) "";
    (* build the model *)
    let model = 
      Model.build (model_name prefs) (emperical_freqs prefs)
                  opt_freqs_transitions ref_align 
                  (Gamma.discrete_gamma 
                    (gamma_n_cat prefs) (gamma_alpha prefs)) in
    (* analyze query sequences *)
    let collect ret_code query_aln_fname =
      try
        let frc = 0 in
        let query_align = 
          Alignment.uppercase (Alignment.read_align query_aln_fname) in
        AlignmentFuns.check_for_repeats (Alignment.getNameArr query_align);
        let query_bname = Filename.chop_extension query_aln_fname in
        let out_ch = 
          open_out (query_bname^".place") in
        Printf.fprintf out_ch "# pplacer %s run, %s\n"        
          version_str (Base.date_time_str ());
        Printf.fprintf out_ch 
          "# invocation: %s\n" (String.concat " " (Array.to_list Sys.argv));
        Prefs.write_prefs out_ch prefs;
        if not (Stree.multifurcating_at_root ref_tree.Stree.tree) then
          Printf.fprintf out_ch "# %s\n" bifurcation_warning;
        Printf.fprintf out_ch "# numbered reference tree: %s\n"
        (Stree_io.to_newick_numbered ref_tree);
        Printf.fprintf out_ch "# reference tree: %s\n" (Stree_io.to_newick ref_tree);
        let prior = 
          if uniform_prior prefs then Core.Uniform_prior
          else Core.Exponential_prior (
            (* exponential with mean = average branch length *)
            (Stree.tree_length ref_tree) /. 
              (float_of_int (Stree.n_edges ref_tree.Stree.tree))) 
        in
        let results = 
          Core.pplacer_core prefs prior
          model ref_align ref_tree query_align in
        if only_write_best prefs then
          (* this is for backward compatibility *)
          Placement_io.write_best_of_placement_arr 
            out_ch (calc_pp prefs) results
        else begin
          (* placements sorted by ml, new version *)
          let (placed_map, unplaced_list) = 
            Placement.sorted_npcl_map_by_best_loc_of_npc_list 
              Placement.ml_ratio
              (Array.to_list results)
          in
          if unplaced_list <> [] then
            Printf.fprintf out_ch "# unplaced sequences\n";
          List.iter
            (fun name -> Printf.fprintf out_ch ">%s\n" name) 
            unplaced_list;
          Placement_io.write_npcl_map out_ch placed_map;
          let fasta_ch = open_out (query_bname^".loc.fasta")
          and amap = Alignment.to_map_by_name query_align
          in 
          let write_by_name name = 
            try 
              Alignment.write_fasta_line fasta_ch
                (name, StringMap.find name amap)
            with
            | Not_found -> failwith (name^" not found in fasta_file_by_npcl_map")
          in
          if unplaced_list <> [] then begin
            Printf.fprintf fasta_ch ">unplaced_sequences\n-\n";
            List.iter write_by_name unplaced_list
          end;
          IntMap.iter
            (fun loc npcl ->
              Printf.fprintf fasta_ch ">placed_at_%d\n-\n" loc;
              List.iter 
                (fun (name, _) -> write_by_name name)
                npcl)
            placed_map;
          close_out fasta_ch;
          close_out out_ch
        end;
        if frc = 0 && ret_code = 1 then 0 else ret_code
      with Sys_error msg -> prerr_endline msg; 2 in
    let retVal = List.fold_left collect 1 files in
    if verb_level prefs > 0 then Common_base.printElapsedTime ();
    exit retVal
  end
