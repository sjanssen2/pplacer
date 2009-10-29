(* pplacer v0.3. Copyright (C) 2009  Frederick A
 * Matsen.warn_about_duplicate_names combined;
 * This file is part of pplacer. pplacer is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. pplacer is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with pplacer. If not, see <http://www.gnu.org/licenses/>.
 *)

open MapsSets
open Fam_batteries
open Itree


(* output *)

let print_tree_info tree = 
  let info = get_info tree in
  List.iter
    (fun id -> 
      Printf.printf "%d:\t%s\n" id (Itree_info.entry_to_string info id))
    (Stree.collect_node_numbers (Itree.get_stree tree))

let to_newick_gen entry_to_str istree = 
  let rec aux = function
    | Stree.Node(i, tL) ->
        "("^(String.concat "," (List.map aux tL))^")"^
        (entry_to_str istree.info i)
    | Stree.Leaf i -> entry_to_str istree.info i
  in
  (aux (Itree.get_stree istree))^";"

let to_newick = to_newick_gen Itree_info.entry_to_string
let to_newick_numbered = 
  to_newick_gen (fun _ i -> string_of_int i)

let write_newick ch istree = 
  Printf.fprintf ch "%s\n" (to_newick istree)

let rec ppr_gen_itree ppr_node ff = function
  | Stree.Node(i, tL) ->
      Format.fprintf ff "@[(";
      Ppr.ppr_gen_list_inners "," (ppr_gen_itree ppr_node) ff tL;
      Format.fprintf ff ")";
      ppr_node ff i;
      Format.fprintf ff "@]"
  | Stree.Leaf(i) -> ppr_node ff i

let ppr_numbered_itree = ppr_gen_itree Format.pp_print_int

let ppr_itree ff itree = 
  ppr_gen_itree (
    fun ff i -> Format.fprintf ff "%s" (Itree_info.entry_to_string itree.info i)
  ) ff itree.stree

let make_numbered_tree tree =
  Itree.make_boot_node_num 
    (Itree.itree 
      (Itree.get_stree tree)
      {(Itree.get_info tree) with 
      Itree_info.taxon = 
        (IntMap.map 
        (fun s -> s^"@")
        ((Itree.get_info tree).Itree_info.taxon))})


(* input *)

(* count the number of occurrences of char c in str *)
let count_n_occurrences c str = 
  let count = ref 0 in
  String.iter (fun d -> if c = d then incr count) str;
  !count

let check_newick_str s = 
  let n_open = count_n_occurrences '(' s 
  and n_closed = count_n_occurrences ')' s in
  if n_open <> n_closed then
    Printf.printf "warning: %d open parens and %d closed parens\n" n_open n_closed;
  ()

let of_newick_lexbuf lexbuf = 
  try
    Itree_parser.tree Itree_lexer.token lexbuf
  with 
  | Parsing.Parse_error -> failwith "couldn't parse tree!"

let of_newick_str s = 
  check_newick_str s;
  of_newick_lexbuf 
  (Lexing.from_string (Str.replace_first (Str.regexp ");") "):0.;" s))

let of_newick_file fname = 
  match
    List.filter 
      (fun line -> 
        not (Str.string_match (Str.regexp "^[ \t]*$") line 0)) 
      (Common_base.stringListOfFile fname)
  with
    | [] -> failwith ("empty file in "^fname)
    | [s] -> of_newick_str s
    | _ -> failwith ("expected a single tree on a single line in "^fname)

let listOfNewickFile fname =
  List.map of_newick_str (Common_base.stringListOfFile fname)