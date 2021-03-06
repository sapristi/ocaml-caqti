(* Copyright (C) 2017--2019  Petter A. Urkedal <paurkedal@gmail.com>
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version, with the OCaml static compilation exception.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *)

open Caqti_compat [@@warning "-33"]

type _ field = ..

type _ field +=
  | Bool : bool field
  | Int : int field
  | Int32 : int32 field
  | Int64 : int64 field
  | Float : float field
  | String : string field
  | Octets : string field
  | Pdate : Ptime.t field
  | Ptime : Ptime.t field
  | Ptime_span : Ptime.span field

module Field = struct

  type 'a t = 'a field

  type _ coding = Coding : {
    rep: 'b t;
    encode: 'a -> ('b, string) result;
    decode: 'b -> ('a, string) result;
  } -> 'a coding

  type get_coding = {get_coding: 'a. Caqti_driver_info.t -> 'a t -> 'a coding}

  let coding_ht : (extension_constructor, get_coding) Hashtbl.t =
    Hashtbl.create 11

  let define_coding ft get =
    let ec = Obj.Extension_constructor.of_val ft in
    Hashtbl.add coding_ht ec get

  let coding di ft =
    let ec = Obj.Extension_constructor.of_val ft in
    try Some ((Hashtbl.find coding_ht ec).get_coding di ft)
    with Not_found -> None

  let to_string : type a. a field -> string = function
   | Bool -> "bool"
   | Int -> "int"
   | Int32 -> "int32"
   | Int64 -> "int64"
   | Float -> "float"
   | String -> "string"
   | Octets -> "octets"
   | Pdate -> "pdate"
   | Ptime -> "ptime"
   | Ptime_span -> "ptime_span"
   | ft -> Obj.Extension_constructor.name (Obj.Extension_constructor.of_val ft)
end

type _ t =
  | Unit : unit t
  | Field : 'a field -> 'a t
  | Option : 'a t -> 'a option t
  | Tup2 : 'a0 t * 'a1 t -> ('a0 * 'a1) t
  | Tup3 : 'a0 t * 'a1 t * 'a2 t -> ('a0 * 'a1 * 'a2) t
  | Tup4 : 'a0 t * 'a1 t * 'a2 t * 'a3 t -> ('a0 * 'a1 * 'a2 * 'a3) t
  | Custom : {
      rep: 'b t;
      encode: 'a -> ('b, string) result;
      decode: 'b -> ('a, string) result;
    } -> 'a t

type any = Any : 'a t -> any

let rec length : type a. a t -> int = function
 | Unit -> 0
 | Field _ -> 1
 | Option t -> length t
 | Tup2 (t0, t1) -> length t0 + length t1
 | Tup3 (t0, t1, t2) -> length t0 + length t1 + length t2
 | Tup4 (t0, t1, t2, t3) -> length t0 + length t1 + length t2 + length t3
 | Custom {rep; _} -> length rep

let rec pp_at : type a. int -> Format.formatter -> a t -> unit =
    fun prec ppf -> function
 | Unit -> Format.pp_print_string ppf "unit"
 | Field ft -> Format.pp_print_string ppf (Field.to_string ft)
 | Option t -> pp_at 1 ppf t; Format.pp_print_string ppf " option"
 | Tup2 (t0, t1) ->
    if prec > 0 then Format.pp_print_char ppf '(';
    pp_at 1 ppf t0;
    Format.pp_print_string ppf " × ";
    pp_at 1 ppf t1;
    if prec > 0 then Format.pp_print_char ppf ')'
 | Tup3 (t0, t1, t2) ->
    if prec > 0 then Format.pp_print_char ppf '(';
    pp_at 1 ppf t0;
    Format.pp_print_string ppf " × ";
    pp_at 1 ppf t1;
    Format.pp_print_string ppf " × ";
    pp_at 1 ppf t2;
    if prec > 0 then Format.pp_print_char ppf ')'
 | Tup4 (t0, t1, t2, t3) ->
    if prec > 0 then Format.pp_print_char ppf '(';
    pp_at 1 ppf t0;
    Format.pp_print_string ppf " × ";
    pp_at 1 ppf t1;
    Format.pp_print_string ppf " × ";
    pp_at 1 ppf t2;
    Format.pp_print_string ppf " × ";
    pp_at 1 ppf t3;
    if prec > 0 then Format.pp_print_char ppf ')'
 | Custom {rep; _} ->
    Format.pp_print_string ppf "</";
    pp_at 0 ppf rep;
    Format.pp_print_string ppf "/>"

let pp ppf = pp_at 1 ppf
let pp_any ppf (Any t) = pp_at 1 ppf t

let show t =
  let buf = Buffer.create 64 in
  let ppf = Format.formatter_of_buffer buf in
  pp ppf t;
  Format.pp_print_flush ppf ();
  Buffer.contents buf

let field ft = Field ft

module Std = struct
  let unit = Unit
  let option t = Option t
  let tup2 t0 t1 = Tup2 (t0, t1)
  let tup3 t0 t1 t2 = Tup3 (t0, t1, t2)
  let tup4 t0 t1 t2 t3 = Tup4 (t0, t1, t2, t3)
  let custom ~encode ~decode rep = Custom {rep; encode; decode}

  let bool = Field Bool
  let int = Field Int
  let int32 = Field Int32
  let int64 = Field Int64
  let float = Field Float
  let string = Field String
  let octets = Field Octets
  let pdate = Field Pdate
  let ptime = Field Ptime
  let ptime_span = Field Ptime_span
end
include Std
