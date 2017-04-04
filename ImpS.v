(* FIXME: Copied these from pset4; probably won't need all of them. *)
Require Import Bool Arith List Omega ListSet.
Require Import Recdef Morphisms.
Require Import Program.Tactics.
Require Import Relation_Operators.
Require FMapList.
Require FMapFacts.
Require Import Classical.
Require Import Coq.Classes.RelationClasses.
Require Import OrderedType OrderedTypeEx DecidableType.
Require Import Sorting.Permutation.
Import ListNotations.
Require Common.

Module ImpS.
Include Common.

Section Syntax.
  Inductive exp : Type :=
  | Enat : nat -> exp
  | Evar : var -> exp
  | Eplus : exp -> exp -> exp
  | Emult : exp -> exp -> exp
  | Eloc : location -> exp
  | Ederef : exp -> exp
  | Eisunset : condition -> exp
  | Elambda : mode -> com -> exp
                                   
  with com : Type :=
  | Cskip : com
  | Cassign : var -> exp -> com
  | Cdeclassify : var -> exp -> com
  | Cupdate : exp -> exp -> com
  | Coutput : exp -> sec_level -> com
  | Cset : condition -> com
  | Cseq : list com -> com
  | Cif : exp -> com -> com -> com
  | Cwhile : exp -> com -> com.

  Inductive val : Type :=
  | Vlambda : com -> val
  | Vnat : nat -> val
  | Vloc : location -> val.

  Function exp_novars (e : exp) : Prop :=
    match e with
    | Evar _ => False
    | Eplus e1 e2 => exp_novars e1 /\ exp_novars e2
    | Emult e1 e2 => exp_novars e1 /\ exp_novars e2
    | Ederef e => exp_novars e
    | Elambda md c => com_novars c
    | _ => True
    end
  with com_novars (c : com) : Prop :=
    match c with
    | Cassign _ e => exp_novars e
    | Cdeclassify _ e => exp_novars e
    | Cupdate e1 e2 => exp_novars e1 /\ exp_novars e2
    | Coutput e _ => exp_novars e
    | Cif e _ _ => exp_novars e
    | Cwhile e _ => exp_novars e
    | Ccall e => exp_novars e
    | _ => True
    end.
  
End Syntax.

Section Semantics.
  Definition reg : Type := register val.
  Definition init_regfile : reg := fun x -> Vnat 0.
  Definition mem : Type := memory val.
  Definition loc_mode : Type := location -> mode.

  (* FIXME: what to do about attackers? don't need to model, I'm guessing *)
  Inductive event : Type :=
  | Decl : exp -> mem -> event
  | Mem : mem -> event
  | Out : sec_level -> val -> event
  Definition trace : Type := list event.

  Definition econfig : Type := exp * reg * mem.
  Definition ecfg_exp (ecfg: econfig) : exp :=
    match ecfg with (e, _, _) => e end.
  Definition ecfg_reg (ecfg: econfig) : reg :=
    match ecfg with (_, r, _) => r end.
  Definition ecfg_mem (ecfg: econfig) : mem :=
    match ecfg with (_, _, m) => m end.
  Definition ecfg_update_exp (ecfg: econfig) (e: exp) : econfig :=
    match ecfg with (_, r, m) => (e, r, m) end.
  

  (* Semantics for commands. *)
  Definition cconfig : Type := com * reg * mem
  Definition cterm : Type := reg * mem
  Definition ccfg_com (ccfg: cconfig) : com :=
    match ccfg with (c, _, _) => c end.
  Definition ccfg_reg (ccfg: cconfig) : reg :=
    match ccfg with (_, r, _) => r end.
  Definition ccfg_mem (ccfg: cconfig) : mem :=
    match ccfg with (_, _, m) => m end.
  Definition ccfg_update_mem (ccfg: cconfig) (l: location) (v: val) : mem := 
    fun loc => if locations_eq loc l then v
               else (ccfg_mem ccfg) loc.
  Definition ccfg_update_reg (ccfg: cconfig) (x: var) (v: val) : reg :=
    fun var => if var =? x then v
               else (ccfg_reg ccfg) var.
  Definition ccfg_to_ecfg (e: exp) (ccfg : cconfig) : econfig :=
    (e, (ccfg_reg ccfg), (ccfg_mem ccfg)).
  Definition ccfg_update_com (c: com) (ccfg : cconfig) : cconfig :=
    (c, (ccfg_reg ccfg), (ccfg_mem ccfg)).
                                              
End Semantics.
End ImpS.
