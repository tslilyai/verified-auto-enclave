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
Require Import Coq.Logic.FunctionalExtensionality.
Require Import Sorting.Permutation.
Import ListNotations.
Require Import Common.
Require Import ImpE.

(*******************************************************************************
*
* SYNTAX
*
*******************************************************************************)

Section Syntax.
  Inductive val2 : Type :=
  | VSingle: val -> val2
  | VPair: val -> val -> val2.
End Syntax.

(*******************************************************************************
*
* SEMANTICS
*
*******************************************************************************)

Section Semantics.
  Definition reg2 : Type := register val2.
  Definition reg_init2 : reg2 := fun x => VSingle (Vnat 0).
  Definition mem2 : Type := memory val2.
  Inductive kill2 : Type :=
  | KSingle: set enclave -> kill2
  | KPair: set enclave -> set enclave -> kill2.

  Inductive event2 : Type :=
  | Emp2 : event2
  | Decl2 : exp -> mem2 -> event2
  | Mem2 : mem2 -> event2
  | Out2 : sec_level -> val2 -> event2
  | ANonEnc2 : com -> event2
  | AEnc2 : forall c c' : com, enc_equiv c c' -> event2
  | EPair : event2 -> event2 -> event2.
  Definition trace2 : Type := list event2.

  (* Mode is only alive if it is alive in both of the kill sets in a pair *)
  (* XXX: not sure if this definition is right but it seems reasonable *)
  (* Seems right---both sides of kill pair are equal when it's well-typed *)
  Function mode_alive2 (md : mode) (k : kill2) :=
    match md with
    | Normal => True
    | Encl i =>
      match k with
      | KSingle ks => ~set_In i ks
      | KPair ks1 ks2 => mode_alive md ks1 /\ mode_alive md ks2
      end
    end.
  Definition mode_access_ok2 (md : mode) (d : loc_mode) (l : location) (k : kill2) :=
    let lmd := d l in
    match lmd with
    | Normal => True
    | Encl _ => md = lmd /\ mode_alive2 lmd k
    end.
  Definition val_to_val2 (v: val) : val2 := VSingle v.
  Definition mem_to_mem2 (m: mem) : mem2 := fun x => val_to_val2 (m x).
  Inductive merge_reg (r1 r2: reg) : reg2 -> Prop :=
  | rmerge : forall r,
      (forall x, r1 x <> r2 x -> r x = VPair (r1 x) (r2 x))
      -> (forall y, r1 y = r2 y -> r y = val_to_val2 (r1 y))
      -> merge_reg r1 r2 r.
  Inductive merge_mem (m1 m2: mem) : mem2 -> Prop :=
  | mmerge : forall m,
      (forall x, m1 x <> m2 x -> m x = VPair (m1 x) (m2 x))
      -> (forall y, m1 y = m2 y -> m y = val_to_val2 (m1 y))
      -> merge_mem m1 m2 m.
  Definition event_to_event2 (e: event) : event2 :=
    match e with
      | Mem m => Mem2 (mem_to_mem2 m)
      | Decl e m => Decl2 e (mem_to_mem2 m)
      | Out l v => Out2 l (val_to_val2 v)
      | ANonEnc c => ANonEnc2 c
      | AEnc c1 c2 enc_equiv => AEnc2 c1 c2 enc_equiv
      | Emp => Emp2
    end.
  Definition tracepair_len (t: trace * trace) := length (fst t) + length (snd t).
  Function merge_trace (t: trace * trace) {measure tracepair_len t} : trace2 :=
    match fst t, snd t with
    | a1::tl1, a2::tl2 => EPair (event_to_event2 a1)
                                 (event_to_event2 a2) :: (merge_trace (tl1, tl2))
    | a1::tl1, [] => EPair (event_to_event2 a1) Emp2 :: merge_trace (tl1, [])
    | [], a2::tl2 => EPair Emp2 (event_to_event2 a2) :: merge_trace ([], tl2)
    | _, _ => []
    end.
  Proof. all: intros; unfold tracepair_len; rewrite teq, teq0; simpl; omega. Qed.
  Definition merge_kill (k1 k2: set enclave) := KPair k1 k2.

  Definition add_to_kill2 (e : enclave) (k : kill2) : kill2 :=
    match k with
    | KSingle ks => KSingle (set_add Nat.eq_dec e ks)
    | KPair ks1 ks2 => KPair (set_add Nat.eq_dec e ks1) (set_add Nat.eq_dec e ks2)
    end.
  
  Function project_value (v: val2) (is_left: bool): val :=
    match v with
      (* XXX pretty sure we can't have nested value pairs *)
    | VPair v1 v2 => if is_left then v1 else v2
    | VSingle v => v
    end.
  Definition project_reg (r: reg2) (is_left : bool): reg :=
    fun x => match r x with
             | VPair v1 v2 => if is_left then v1 else v2
             | VSingle v => v
          end.
  Definition project_mem (m: mem2) (is_left : bool): mem :=
    fun x => match m x with
             | VPair v1 v2 => if is_left then v1 else v2
             | VSingle v => v
          end.
  Function project_kill (k: kill2) (is_left : bool) : set enclave :=
    match k with
    | KPair ks1 ks2 => if is_left then ks1 else ks2
    | KSingle k => k
    end.
  
  Lemma mode_alive_project_alive : forall md k is_left,
      mode_alive2 md k -> mode_alive md (project_kill k is_left).
  Proof.
    intros.
    destruct k; simpl; auto.
    destruct md; simpl; auto; unfold mode_alive2 in H; destruct_conjs.
    destruct is_left; unfold mode_alive in *; auto.
  Qed.

  Lemma mode_access_ok_project_ok : forall md d l k is_left,
      mode_access_ok2 md d l k -> mode_access_ok md d l (project_kill k is_left).
    intros.
    destruct k; simpl; auto.
    assert ((if is_left then s else s0) = project_kill (KPair s s0) is_left) by
        (destruct is_left; auto);
    destruct md; simpl; auto; unfold mode_access_ok2 in H; destruct_conjs;
    remember (d l) as mem_mode; destruct mem_mode; unfold mode_access_ok;
      rewrite <- Heqmem_mode; auto; destruct_conjs; split; auto;
    rewrite H0; apply mode_alive_project_alive; auto.
  Qed.
  
  (* XXX show event pairs are never nested *)
  Function event2_to_event (e: event2) (is_left: bool): event :=
     match e with
      | Mem2 m => Mem (project_mem m is_left)
      | Decl2 e m => Decl e (project_mem m is_left)
      | Out2 l v => Out l (project_value v is_left)
      | ANonEnc2 c => ANonEnc c
      | AEnc2 c1 c2 enc_equiv => AEnc c1 c2 enc_equiv
      | EPair e1 e2 => if is_left then event2_to_event e1 is_left
                        else event2_to_event e2 is_left
      | Emp2 => Emp
     end.
  Function project_trace (t: trace2) (is_left : bool) : trace :=
    match t with
    | [] => []
    | hd :: tl => let hd_proj := (event2_to_event hd is_left) in
      match hd_proj with
      | Emp => project_trace tl is_left
      | _ => hd_proj :: project_trace tl is_left
      end
    end.
  
  Definition econfig2 : Type := exp * reg2 * mem2 * kill2.
  Definition ecfg_exp2 (ecfg: econfig2) : exp :=
    match ecfg with (e, _, _, _) => e end.
  Definition ecfg_reg2 (ecfg: econfig2) : reg2 :=
    match ecfg with (_, r, _, _) => r end.
  Definition ecfg_mem2 (ecfg: econfig2) : mem2 :=
    match ecfg with (_, _, m, _) => m end.
  Definition ecfg_kill2 (ecfg: econfig2) : kill2 :=
    match ecfg with (_, _, _, k) => k end.
  Definition ecfg_update_exp2 (ecfg: econfig2) (e: exp) : econfig2 :=
    match ecfg with (_, r, m, k) => (e, r, m, k) end.
  Definition esemantics2 : Type := mode -> loc_mode -> econfig2 -> val2 -> Prop.

   Definition project_ecfg (ecfg : econfig2) (is_left : bool) : econfig :=
    (ecfg_exp2 ecfg, project_reg (ecfg_reg2 ecfg) is_left,
     project_mem (ecfg_mem2 ecfg) is_left, project_kill (ecfg_kill2 ecfg) is_left).

  Inductive estep2 : esemantics2 :=
  | Estep2_nat : forall md d ecfg n,
      ecfg_exp2 ecfg = Enat n ->
      estep2 md d ecfg (VSingle (Vnat n))
  | Estep2_loc : forall md d ecfg l,
      ecfg_exp2 ecfg = Eloc l ->
      estep2 md d ecfg (VSingle (Vloc l))
  | Estep2_lambda : forall md d ecfg c,
      ecfg_exp2 ecfg = Elambda md c ->
      estep2 md d ecfg (VSingle (Vlambda md c))
  | Estep2_var : forall md d ecfg x v,
      ecfg_exp2 ecfg = Evar x ->
      ecfg_reg2 ecfg x = v ->
      estep2 md d ecfg v
  | Estep2_binop : forall md d ecfg e1 e2 n1 n2 op,
      ecfg_exp2 ecfg = Ebinop e1 e2 op ->
      estep2 md d (ecfg_update_exp2 ecfg e1) (VSingle (Vnat n1)) ->
      estep2 md d (ecfg_update_exp2 ecfg e2) (VSingle (Vnat n2)) ->
      estep2 md d ecfg (VSingle (Vnat (op n1 n2)))
  | Estep2_deref : forall md d ecfg e r m k l v,
      ecfg = (Ederef e, r, m, k) ->
      estep2 md d (e, r, m, k) (VSingle (Vloc l)) ->
      m l = v ->
      mode_access_ok2 md d l k ->
      estep2 md d ecfg v
  | Estep2_isunset : forall md d ecfg cnd v res,
      ecfg_exp2 ecfg = Eisunset cnd ->
      estep2 md d (ecfg_update_exp2 ecfg (Ederef (Eloc (Cnd cnd)))) v ->
      (v = VSingle (Vnat 0) /\ res = VSingle (Vnat 1))
      \/ (v = VSingle (Vnat 1) /\ res = VSingle (Vnat 0)) ->
      estep2 md d ecfg res.

  (* Semantics for commands. *)
  Definition cconfig2 : Type := com * reg2 * mem2 * kill2.
  Definition cterm2 : Type := reg2 * mem2 * kill2.
  Definition ccfg_com2 (ccfg: cconfig2) : com :=
    match ccfg with (c, _, _, _) => c end.
  Definition ccfg_reg2 (ccfg: cconfig2) : reg2 :=
    match ccfg with (_, r, _, _) => r end.
  Definition ccfg_mem2 (ccfg: cconfig2) : mem2 :=
    match ccfg with (_, _, m, _) => m end.
  Definition ccfg_kill2 (ccfg: cconfig2) : kill2 :=
    match ccfg with (_, _, _, k) => k end.
  Definition ccfg_update_mem2 (ccfg: cconfig2) (l: location) (v: val2) : mem2 := 
    fun loc => if locations_eq loc l then v
               else (ccfg_mem2 ccfg) loc.
  Definition ccfg_update_reg2 (ccfg: cconfig2) (x: var) (v: val2) : reg2 :=
    fun var => if var =? x then v
               else (ccfg_reg2 ccfg) var.
  Definition ccfg_to_ecfg2 (e: exp) (ccfg : cconfig2) : econfig2 :=
    (e, (ccfg_reg2 ccfg), (ccfg_mem2 ccfg), (ccfg_kill2 ccfg)).
  Definition ccfg_update_com2 (c: com) (ccfg : cconfig2) : cconfig2 :=
    (c, (ccfg_reg2 ccfg), (ccfg_mem2 ccfg), (ccfg_kill2 ccfg)).
  Definition csemantics2 : Type := mode -> loc_mode -> cconfig2 -> cterm2 -> trace2 -> Prop.  

  Definition project_ccfg (ccfg : cconfig2) (is_left : bool) : cconfig :=
    (ccfg_com2 ccfg, project_reg (ccfg_reg2 ccfg) is_left,
     project_mem (ccfg_mem2 ccfg) is_left, project_kill (ccfg_kill2 ccfg) is_left).

  Inductive cstep2 : csemantics2 := 
  | Cstep2_skip : forall md d ccfg,
      ccfg_com2 ccfg = Cskip ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, ccfg_mem2 ccfg, ccfg_kill2 ccfg) []
  | Cstep2_assign : forall md d ccfg x e v r',
      ccfg_com2 ccfg = Cassign x e ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) v ->
      r' = ccfg_update_reg2 ccfg x v ->
      mode_alive2 md (ccfg_kill2 ccfg) ->
      cstep2 md d ccfg (r', ccfg_mem2 ccfg, ccfg_kill2 ccfg) []
  | Cstep2_declassify : forall md d ccfg x e v r',
      ccfg_com2 ccfg = Cdeclassify x e ->
      exp_novars e ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) v ->
      r' = ccfg_update_reg2 ccfg x v ->
      mode_alive2 md (ccfg_kill2 ccfg) ->
      cstep2 md d ccfg (r', ccfg_mem2 ccfg, ccfg_kill2 ccfg) [Decl2 e (ccfg_mem2 ccfg)]
  | Cstep2_update : forall md d ccfg e1 e2 l v m',
      ccfg_com2 ccfg = Cupdate e1 e2 ->
      estep2 md d (ccfg_to_ecfg2 e1 ccfg) (VSingle (Vloc l)) ->
      estep2 md d (ccfg_to_ecfg2 e2 ccfg) v ->
      mode_alive2 md (ccfg_kill2 ccfg) ->
      mode_access_ok2 md d l (ccfg_kill2 ccfg) ->
      is_Not_cnd l ->
      m' = ccfg_update_mem2 ccfg l v ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, m', ccfg_kill2 ccfg) []
  | Cstep2_output : forall md d ccfg e sl v,
      ccfg_com2 ccfg = Coutput e sl ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) v ->
      sl = L \/ sl = H ->
      mode_alive2 md (ccfg_kill2 ccfg) ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, ccfg_mem2 ccfg, ccfg_kill2 ccfg)
            [Mem2 (ccfg_mem2 ccfg); Out2 sl v]
  | Cstep2_call : forall md d ccfg e c r' m' k' tr,
      ccfg_com2 ccfg = Ccall e ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VSingle (Vlambda md c)) ->
      cstep2 md d (ccfg_update_com2 c ccfg) (r', m', k') tr ->
      cstep2 md d ccfg (r', m', k') tr
  | Cstep2_call_div : forall md d ccfg e c1 c2 r1 m1 k1 t1 r2 m2 k2 t2 rmerge mmerge,
      ccfg_com2 ccfg = Ccall e ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VPair (Vlambda md c1) (Vlambda md c2)) ->
      cstep md d (c1, project_reg (ccfg_reg2 ccfg) true,
                  project_mem (ccfg_mem2 ccfg) true,
                  project_kill (ccfg_kill2 ccfg) true)
             (r1, m1, k1) t1 ->
      cstep md d (c2, project_reg (ccfg_reg2 ccfg) false,
                  project_mem (ccfg_mem2 ccfg) false,
                  project_kill (ccfg_kill2 ccfg) false)
            (r2, m2, k2) t2 ->
      merge_reg r1 r2 rmerge ->
      merge_mem m1 m2 mmerge ->
      cstep2 md d ccfg (rmerge, mmerge, merge_kill k1 k2) (merge_trace (t1, t2))
  | Cstep2_cset : forall md d ccfg c m',
      ccfg_com2 ccfg = Cset c ->
      mode_access_ok2 md d (Cnd c) (ccfg_kill2 ccfg) ->
      m' = ccfg_update_mem2 ccfg (Cnd c) (VSingle (Vnat 1)) ->
      mode_alive2 md (ccfg_kill2 ccfg) ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, m', ccfg_kill2 ccfg) [Mem2 m']
  | Cstep2_enclave : forall md d ccfg enc c r' m' k' tr,
    md = Normal ->
    ccfg_com2 ccfg = Cenclave enc c ->
    cstep2 (Encl enc) d (c, ccfg_reg2 ccfg, ccfg_mem2 ccfg, ccfg_kill2 ccfg) (r', m', k') tr ->
    cstep2 md d ccfg (r', m', k') tr
  | Cstep2_seq_nil : forall md d ccfg,
      ccfg_com2 ccfg = Cseq [] ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, ccfg_mem2 ccfg, ccfg_kill2 ccfg) []
  | Cstep2_seq_hd : forall md d ccfg hd tl r m k tr r' m' k' tr',
      ccfg_com2 ccfg = Cseq (hd::tl) ->
      cstep2 md d (ccfg_update_com2 hd ccfg) (r, m, k) tr ->
      cstep2 md d (Cseq tl, r, m, k) (r', m', k') tr' ->
      cstep2 md d ccfg (r', m', k') (tr++tr')
  | Cstep2_if : forall md d ccfg e c1 c2 r' m' k' tr,
      ccfg_com2 ccfg = Cif e c1 c2 ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VSingle (Vnat 1)) ->
      cstep2 md d (ccfg_update_com2 c1 ccfg) (r', m', k') tr ->
      cstep2 md d ccfg (r', m', k') tr
  | Cstep2_else : forall md d ccfg e c1 c2 r' m' k' tr,
      ccfg_com2 ccfg = Cif e c1 c2 ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VSingle (Vnat 0)) ->
      cstep2 md d (ccfg_update_com2 c2 ccfg) (r', m', k') tr ->
      cstep2 md d ccfg (r', m', k') tr
  | Cstep2_if_div : forall md d ccfg e c1 c2 n1 n2 r1 m1 k1 t1 r2 m2 k2 t2 rmerge mmerge,
      ccfg_com2 ccfg = Cif e c1 c2 ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VPair (Vnat n1) (Vnat n2)) ->
      let cleft := (match n1 with
                    | 0 => c2
                    | _ => c1 end) in
      cstep md d (cleft, project_reg (ccfg_reg2 ccfg) true,
                  project_mem (ccfg_mem2 ccfg) true,
                  project_kill (ccfg_kill2 ccfg) true)
             (r1, m1, k1) t1 ->
      let cright := (match n2 with
                     | 0 => c2
                     | _ => c1 end) in
      cstep md d (cright, project_reg (ccfg_reg2 ccfg) false,
                  project_mem (ccfg_mem2 ccfg) false,
                  project_kill (ccfg_kill2 ccfg) false)
            (r2, m2, k2) t2 ->
      merge_reg r1 r2 rmerge ->
      merge_mem m1 m2 mmerge ->
      cstep2 md d ccfg (rmerge, mmerge, merge_kill k1 k2) (merge_trace (t1, t2))
  | Cstep2_while_t : forall md d ccfg e c r m k tr r' m' k' tr',
      ccfg_com2 ccfg = Cwhile e c ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VSingle (Vnat 1)) ->
      cstep2 md d (ccfg_update_com2 c ccfg) (r, m, k) tr ->
      cstep2 md d (ccfg_update_com2 (Cwhile e c) ccfg) (r', m', k') tr' ->
      cstep2 md d ccfg (r', m', k') (tr++tr')
  | Cstep2_while_f : forall md d ccfg e c,
      ccfg_com2 ccfg = Cwhile e c ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VSingle (Vnat 0)) ->
      mode_alive2 md (ccfg_kill2 ccfg) ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, ccfg_mem2 ccfg, ccfg_kill2 ccfg) []
  | Cstep2_while_div : forall md d ccfg e c n1 n2 r1 m1 k1 t1 r2 m2 k2 t2 rmerge mmerge,
      ccfg_com2 ccfg = Cwhile e c ->
      estep2 md d (ccfg_to_ecfg2 e ccfg) (VPair (Vnat n1) (Vnat n2)) ->
      let cleft := (match n1 with
                    | 0 => Cskip
                    | _ => c end) in
      cstep md d (cleft, project_reg (ccfg_reg2 ccfg) true,
                  project_mem (ccfg_mem2 ccfg) true,
                  project_kill (ccfg_kill2 ccfg) true)
             (r1, m1, k1) t1 ->
      let cright := (match n2 with
                     | 0 => Cskip
                     | _ => c end) in
      cstep md d (cright, project_reg (ccfg_reg2 ccfg) false,
                  project_mem (ccfg_mem2 ccfg) false,
                  project_kill (ccfg_kill2 ccfg) false)
            (r2, m2, k2) t2 ->
      merge_reg r1 r2 rmerge ->
      merge_mem m1 m2 mmerge ->
      cstep2 md d ccfg (rmerge, mmerge, merge_kill k1 k2) (merge_trace (t1, t2))
  | Cstep2_kill : forall md d ccfg enc,
      md = Normal ->
      ccfg_com2 ccfg = Ckill enc ->
      mode_alive2 (Encl enc) (ccfg_kill2 ccfg) ->
      cstep2 md d ccfg (ccfg_reg2 ccfg, ccfg_mem2 ccfg, add_to_kill2 enc (ccfg_kill2 ccfg)) [].
  
  Hint Constructors cstep2.

  Inductive imm_premise : Prop -> Prop -> Prop :=
  | IPcall: forall md d e r m k r' m' k' tr c,
      estep2 md d (e, r, m, k) (VSingle (Vlambda md c)) ->
      cstep2 md d (c, r, m, k) (r', m', k') tr ->
      imm_premise (cstep2 md d (c, r, m, k) (r', m', k') tr)
                  (cstep2 md d (Ccall e, r, m, k) (r', m', k') tr)
  | IPencl: forall d encl c r m k r' m' k' tr,
      cstep2 (Encl encl) d (c, r, m, k) (r', m', k') tr ->
      imm_premise (cstep2 (Encl encl) d (c, r, m, k) (r', m', k') tr)
                  (cstep2 Normal d (Cenclave encl c, r, m, k) (r', m', k') tr)
  | IPseq1: forall md d c rest r m k r' m' k' r'' m'' k'' tr tr',
      cstep2 md d (c, r, m, k) (r', m', k') tr' ->
      cstep2 md d (Cseq rest, r', m', k') (r'', m'', k'') tr ->
      imm_premise (cstep2 md d (c, r, m, k) (r', m', k') tr')
                  (cstep2 md d (Cseq (c :: rest), r, m, k) (r'', m'', k'')
                          (tr' ++ tr))
  | IPseq2: forall md d c rest r m k r' m' k' r'' m'' k'' tr tr',
      cstep2 md d (c, r, m, k) (r', m', k') tr' ->
      cstep2 md d (Cseq rest, r', m', k') (r'', m'', k'') tr ->
      imm_premise (cstep2 md d (Cseq rest, r', m', k') (r'', m'', k'') tr)
                  (cstep2 md d (Cseq (c :: rest), r, m, k) (r'', m'', k'')
                          (tr' ++ tr))
  | IPif: forall md d c1 c2 e r m k r' m' k' tr tr',
      estep2 md d (e, r, m, k) (VSingle (Vnat 1)) ->
      cstep2 md d (c1, r, m, k) (r', m', k') tr' ->
      cstep2 md d (Cif e c1 c2, r, m, k) (r', m', k') tr ->
      imm_premise (cstep2 md d (c1, r, m, k) (r', m', k') tr)
                  (cstep2 md d (Cif e c1 c2, r, m, k) (r', m', k')
                          (tr' ++ tr))
  | IPelse: forall md d c1 c2 e r m k r' m' k' tr tr',
      estep2 md d (e, r, m, k) (VSingle (Vnat 0)) ->
      cstep2 md d (c2, r, m, k) (r', m', k') tr' ->
      cstep2 md d (Cif e c1 c2, r, m, k) (r', m', k') tr ->
      imm_premise (cstep2 md d (c2, r, m, k) (r', m', k') tr)
                  (cstep2 md d (Cif e c1 c2, r, m, k) (r', m', k')
                          (tr' ++ tr))
  | IPwhilet1: forall md d c e r m k r' m' k' r'' m'' k'' tr tr',
      estep2 md d (e, r, m, k) (VSingle (Vnat 1)) ->
      cstep2 md d (c, r, m, k) (r', m', k') tr' ->
      cstep2 md d (Cwhile e c, r', m', k') (r'', m'', k'') tr ->
      imm_premise (cstep2 md d (c, r, m, k) (r'', m'', k'') tr')
                  (cstep2 md d (Cwhile e c, r, m, k) (r'', m'', k'')
                          (tr' ++ tr))
  | IPwhilet2: forall md d c e r m k r' m' k' r'' m'' k'' tr tr',
      estep2 md d (e, r, m, k) (VSingle (Vnat 1)) ->
      cstep2 md d (c, r, m, k) (r', m', k') tr' ->
      cstep2 md d (Cwhile e c, r', m', k') (r'', m'', k'') tr ->
      imm_premise (cstep2 md d (Cwhile e c, r', m', k') (r'', m'', k'') tr)
                  (cstep2 md d (Cwhile e c, r, m, k) (r'', m'', k'')
                          (tr' ++ tr))
  .
  Hint Constructors imm_premise.
End Semantics.
  
Section Preservation.

  Ltac unfold_cfgs :=
    unfold ccfg_update_reg2 in *;
    unfold ccfg_to_ecfg2 in *;
    unfold ccfg_reg2 in *;
    unfold ccfg_mem2 in *;
    unfold ccfg_kill2 in *;
    unfold ccfg_com2 in *;
    unfold ecfg_exp2 in *;
    unfold ecfg_reg2 in *;
    unfold ecfg_update_exp2 in *.                      

  Definition cterm2_ok (G: context) (d: loc_mode) (S: set condition) (H: set esc_hatch)
             (m0: mem2) (r: reg2) (m: mem2) (K: kill2) : Prop :=
      (forall x v1 v2 bt p,
          (r x = VPair v1 v2 /\ (var_context G) x = Some (Typ bt p)) -> protected p S) 
      /\ (forall l v1 v2 bt p rt,
          (m (Not_cnd l) = VPair v1 v2 /\ (loc_context G) (Not_cnd l) = Some (Typ bt p, rt))
          -> protected p S)
      /\ (forall e v md', set_In e H ->
                          is_esc_hatch e ->
                          (estep2 md' d (e, reg_init2, m0, K) v ->
                           estep2 md' d (e, r, m, K) v))
      /\ project_kill K true = project_kill K false.

  Definition cconfig2_ok (pc: sec_policy) (md: mode) (G: context) (U: set condition)
             (d: loc_mode) (S: set condition) (H: set esc_hatch) (m0: mem2)
             (ccfg2: cconfig2) (G': context) (K': kill2) : Prop :=
    (forall i, set_In i U -> (ccfg_mem2 ccfg2) (Cnd i) = VSingle (Vnat 0))
    (* unsure about this kill set thing.. pretty sure we can assume this from lemma 3 *)
    /\  com_type pc md G (project_kill (ccfg_kill2 ccfg2) true) U d
                 (ccfg_com2 ccfg2) G' (project_kill K' true)
    /\ (forall x v1 v2 bt p,
           ((ccfg_reg2 ccfg2) x = VPair v1 v2
            /\ (var_context G) x = Some (Typ bt p))
           -> protected p S)
    /\ (forall l v1 v2 bt p rt,
           ((ccfg_mem2 ccfg2) (Not_cnd l) = VPair v1 v2
            /\ (loc_context G) (Not_cnd l) = Some (Typ bt p, rt))    
           -> protected p S)
    /\ (forall e v md', set_In e H ->
                        is_esc_hatch e ->
                        (estep2 md' d  (e, reg_init2, m0, ccfg_kill2 ccfg2) v ->
                         estep2 md' d (e, ccfg_reg2 ccfg2, ccfg_mem2 ccfg2, ccfg_kill2 ccfg2) v))
    /\ project_kill (ccfg_kill2 ccfg2) true = project_kill (ccfg_kill2 ccfg2) false.

  Lemma esc_hatch_reg_irrelevance (e : esc_hatch) :
    forall md d r m k v r',
    is_esc_hatch e -> estep2 md d (e, r, m, k) v ->
    estep2 md d (e, r', m, k) v.
  Proof.
    intros. unfold is_esc_hatch in *.
    remember (e, r, m, k) as ecfg2.
    generalize dependent e.
    induction H0; intros; subst; auto.
    1-3: constructor; unfold_cfgs; auto.
    - unfold_cfgs. subst. unfold exp_novars in H1. simpl in H1. omega.
    - unfold_cfgs; subst.
      assert (exp_novars e1 /\ exp_novars e2). unfold exp_novars in *;
                                                 inversion H0; destruct_pairs; auto.
      destruct_pairs.
      pose (IHestep2_1 e1 H). pose (IHestep2_2 e2 H1).
      apply (Estep2_binop md d (Ebinop e1 e2 op,r',m,k) e1 e2 n1 n2); unfold_cfgs; auto.
    - inversion Heqecfg2; subst.
      assert (exp_novars e). unfold exp_novars in *. inversion H3; auto.
      apply (Estep2_deref md d (Ederef e,r',m,k) e r' m k l (m l)); unfold_cfgs; auto.
    - unfold_cfgs. subst.
      apply (Estep2_isunset md d (Eisunset cnd,r',m,k) cnd v); unfold_cfgs; auto.
      assert (exp_novars (Ederef (Eloc (Cnd cnd)))). unfold exp_novars. simpl; auto.
      apply IHestep2 in H; auto.
  Qed.

  Lemma econfig2_pair_protected : forall md G d e p r m k v v1 v2 S bt H m0,
      v = VPair v1 v2 ->
      exp_type md G d e (Typ bt p) ->
      estep2 md d (e,r,m,k) v ->
      (forall l, (m l) = v ->
                 (exists n, l = Not_cnd n)) ->
      (* XXX assume that if the value is a location, then the policy on the location *)
      (* is protected by S. This should be fine because we're assuming this for *)
      (* memories that are indistinguishable *)
      (forall bt' (p' q: sec_policy) md' rt,
          (Typ bt p = Typ (Tref (Typ bt' p') md' rt) q) /\ protected q S) ->
      cterm2_ok G d S H m0 r m k ->
      protected p S.
  Proof.
    intros.
    remember (e,r,m,k) as ecfg.
    generalize dependent e.
    induction H2; intros; subst; try discriminate; unfold_cfgs;
    unfold cterm2_ok in H5; destruct_pairs; subst.
    - inversion H6; subst.
      apply (H0 x v1 v2 bt p); split; auto. 
    - inversion Heqecfg; subst.
      clear IHestep2.
      inversion H8; subst.
      destruct (H4 bt p0 q md' rt).
      apply (join_protected_r S p0 q); auto.
    - destruct H6; destruct_pairs; try discriminate.
  Qed.

  Lemma impe2_final_config_preservation 
        (G: context) (d: loc_mode) (S: set condition) (H: set esc_hatch) (m0: mem2) :
      forall G' K' c r m k pc md U r' m' t,
        (forall l e v, loc_in_exp e G l -> m0 l = VSingle v) -> 
        context_wt G d ->
        cconfig2_ok pc md G U d S H m0 (c,r,m,k) G' K' ->
        cstep2 md d (c,r,m,k) (r', m', K') t ->
        cterm2_ok G' d S H m0 r' m' K'.
  Proof.
    intros; remember (c,r,m,k) as ccfg2; subst.
    unfold cconfig2_ok in H2; destruct_pairs.
    induction c; unfold cterm2_ok; intros; subst; simpl in *; unfold_cfgs.
    (* CSkip *)
    - inversion H3; try discriminate; subst;
        inversion H4; try discriminate; subst.
      split; [intros | split; intros]; simpl in *; auto.
      -- now apply H5 in H10.
      -- now apply H6 in H10.
    (* CAssign *)
    - inversion H3; try discriminate; subst;
        inversion H4; try discriminate; subst.
      split; [intros | split; intros]; simpl in *; auto; unfold_cfgs.
      -- inversion H12; subst.
         destruct (Nat.eq_dec x0 x).
         --- rewrite <- (Nat.eqb_eq x0 x) in e; rewrite e in H9.
             destruct_pairs.
             assert (protected p S).
             apply (econfig2_pair_protected
                      md (Cntxt vc lc) d e0 p r m' K' v0 v1 v2 S s H m0 _
                      H9 H11 H16).
             inversion H10; subst.
             apply (join_protected_l S p pc H13).
         --- rewrite <- (Nat.eqb_neq x0 x) in n. rewrite n in H9.
             apply H5 in H9; auto.
      -- now apply H6 in H9.
      -- split; intros; auto.
         apply (esc_hatch_reg_irrelevance
                  e1 md' d r m' K' v1
                  (fun var : var => if var =? x then v0 else r var)); auto.
  Admitted.
         
  Lemma impe2_type_preservation
        (G: context) (d: loc_mode) (S: set condition) (H: set esc_hatch) (m0: mem2) :
    forall pc md U c r m K G' K',
      context_wt G d ->
      cconfig2_ok pc md G U d S H m0 (c, r, m, K) G' K' ->
      forall mdmid cmid rmid mmid rmid' mmid' kmid' tmid rfin mfin kfin tfin,
        imm_premise
          (cstep2 mdmid d (cmid, rmid, mmid, K') (rmid', mmid', kmid') tmid)
          (cstep2 md d (c, r, m, K) (rfin, mfin, kfin) tfin) ->
        (exists pcmid Gmid Gmid' Umid,
          policy_le pc pcmid ->
          Umid = [] \/ (forall i, In i U -> In i Umid) ->
          cconfig2_ok pcmid mdmid Gmid Umid d S H m0 (cmid, rmid, mmid, K') Gmid' K').
  Proof.
  Admitted.
 
(*      
  Definition overlap (tr tobs: trace) :=
  | tobs is entirely contained in tr => tobs
  | tobs is after tr => empty
  | overlap with beginning of tobs => beginning of tobs
                                                    
  Lemma eq_overlap_tobs (m1 m2: mem) (tobs: trace) :
    forall md d c k r' m' k' tr1 tr2,
    cstep md d (c, reg_init, m1, k) (r', m', k') tr1 ->
    cstep md d (c, reg_init, m2, k) (r', m', k') tr2 ->
    tobs_sec_level L (overlap tr1 tobs) = tobs_sec_level L (overlap tr2 tobs).
  *)    
End Preservation.


(*******************************************************************************
*
* ADEQUACY
*
*******************************************************************************)
Section Adequacy.

  Definition not_pair_val (v : val2) : Prop :=
    match v with
    | VPair _ _ => False
    | _ => True
    end.

  (* XXX: thought I needed this for exp_output_wf, didn't use it. Might still be useful...? *)
  Lemma estep2_deterministic : forall md d e r m k v1 v2,
    estep2 md d (e, r, m, k) v1 ->
    estep2 md d (e, r, m, k) v2 ->
    v1 = v2.
  Proof.
    intros; revert H0; revert v2.
    induction H; intros; destruct ecfg as [[[e' r'] m'] k']; simpl in *; try rewrite H in H0.
    1-3: inversion H0; subst; try discriminate; simpl in H1; congruence.
    inversion H1; subst; try discriminate; simpl in *; congruence.
    - rewrite H in H2; inversion H2; try discriminate; simpl in *;
        assert (e1 = e0) by congruence; assert (e2 = e3) by congruence;
          subst; apply IHestep2_1 in H4; apply IHestep2_2 in H5; congruence.
    - rewrite H in H3; inversion H3; subst; try discriminate; simpl in *.
      assert (e0 = e1) by congruence.
      assert (r0 = r1) by congruence.
      assert (m0 = m1) by congruence.
      assert (k0 = k1) by congruence.
      subst. apply IHestep2 in H5. assert (l = l0) by congruence; now subst.
    - rewrite H in H2; inversion H2; subst; try discriminate; simpl in *.
      assert (cnd = cnd0) by congruence; subst.
      apply IHestep2 in H4.
      destruct H1; destruct H5; destruct_conjs; subst; auto; congruence.
  Qed.      

  Lemma project_comm_reg : forall r b x,
      (project_reg r b) x = project_value (r x) b.
  Proof.
    intros; unfold project_reg; destruct (r x); auto.
  Qed.

  (* XXX: this might be a pain to prove with registers as functions. Used below in soundness. *)
  Lemma project_update_comm_reg : forall ccfg x v is_left,
      project_reg (ccfg_update_reg2 ccfg x v) is_left = 
      ccfg_update_reg (project_ccfg ccfg is_left) x (project_value v is_left).
  Proof.
  Admitted.

  Lemma project_update_comm_mem : forall ccfg l v is_left,
      project_mem (ccfg_update_mem2 ccfg l v) is_left = 
      ccfg_update_mem (project_ccfg ccfg is_left) l (project_value v is_left).
  Proof.
  Admitted.

  Lemma project_merge_inv_reg : forall r1 r2 r,
      merge_reg r1 r2 r -> (project_reg r true = r1) /\ (project_reg r false = r2).
  Proof.
  Admitted.

  Lemma project_merge_inv_mem : forall m1 m2 m,
      merge_mem m1 m2 m -> (project_mem m true = m1) /\ (project_mem m false = m2).
  Proof.
  Admitted.

  Lemma project_merge_inv_trace : forall t1 t2 is_left,
      project_trace (merge_trace (t1, t2)) is_left = (if is_left then t1 else t2).
  Proof.
  Admitted.

  Lemma project_app_trace : forall t1 t2 is_left,
      project_trace (t1 ++ t2) is_left =
      (project_trace t1 is_left) ++ (project_trace t2 is_left).
  Proof.
  Admitted.

  Lemma impe2_exp_sound : forall md d e r m K v is_left,
      estep2 md d (e, r, m, K) v ->
      estep md d (e, project_reg r is_left, project_mem m is_left, project_kill K is_left)
            (project_value v is_left).
  Proof.
    intros.
    remember (e, r, m, K) as ecfg.
    generalize dependent e.
    induction H; intros; try rewrite Heqecfg in H; simpl in *; try rewrite H.
    1-3: constructor; simpl; auto.
    - apply Estep_var with (x:=x); auto; subst; apply project_comm_reg.
    - apply Estep_binop with (e1:=e1) (e2:=e2); simpl; auto; 
        [apply (IHestep2_1 e1) | apply (IHestep2_2 e2)];
        rewrite Heqecfg; unfold ecfg_update_exp2; auto.
    - inversion H; subst.
      apply Estep_deref with (e:=e) (l:=l) (m:=project_mem m0 is_left)
                                    (r:=project_reg r0 is_left)
                                    (k:=project_kill k is_left); simpl; auto.
      now apply mode_access_ok_project_ok.
    - apply Estep_isunset with (cnd := cnd) (v := (project_value v is_left)); simpl; auto.
      apply IHestep2; subst; auto.
      destruct H1; destruct_conjs; [left | right];
        simpl; split; try (now rewrite H1); try (now rewrite H2).
  Qed.
       
  Lemma impe2_sound : forall md d c r m K r' m' K' t is_left,
    cstep2 md d (c, r, m, K) (r', m', K') t ->
    cstep md d (project_ccfg (c, r, m, K) is_left)
          (project_reg r' is_left, project_mem m' is_left, project_kill K' is_left)
          (project_trace t is_left).
  Proof.
    intros.
    remember (c, r, m, K) as ccfg.
    remember (r', m', K') as cterm.
    generalize dependent r'.
    generalize dependent m'.
    generalize dependent K'.
    generalize dependent c.
    induction H; intros; try rewrite Heqccfg in H, Heqcterm; simpl in *; inversion Heqcterm; subst.
    - constructor.
    - apply impe2_exp_sound with (is_left:=is_left) in H0.
      apply Cstep_assign with (x:=x) (e:=e) (v := project_value v is_left); auto.
      unfold ccfg_to_ecfg; simpl in *; auto.
      apply project_update_comm_reg.
      simpl in *; apply mode_alive_project_alive; auto.
    - apply impe2_exp_sound with (is_left:=is_left) in H1.
      apply Cstep_declassify with (x:=x) (e:=e) (v :=(project_value v is_left)); auto.
      apply project_update_comm_reg.
      now apply mode_alive_project_alive.
    - apply impe2_exp_sound with (is_left:=is_left) in H0.
      apply impe2_exp_sound with (is_left:=is_left) in H1.
      apply Cstep_update with (e1 := e1) (e2 := e2) (l := l) (v := project_value v is_left); auto.
      now apply mode_alive_project_alive.
      now apply mode_access_ok_project_ok.
      now apply project_update_comm_mem.
    - apply impe2_exp_sound with (is_left:=is_left) in H0; simpl in *.
      apply Cstep_output with (e := e); auto.
      now apply mode_alive_project_alive.
    - apply impe2_exp_sound with (is_left:=is_left) in H0; simpl in *.
      apply Cstep_call with (e := e) (c := c); auto.
      apply IHcstep2 with (c1 := c); auto.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *;
        apply project_merge_inv_reg in H3; apply project_merge_inv_mem in H4.
      destruct_conjs; subst.
      destruct is_left;
        [apply Cstep_call with (e:=e) (c:=c1) | apply Cstep_call with (e:=e) (c:=c2)]; auto;
      unfold ccfg_update_com; simpl; rewrite project_merge_inv_trace; auto.
    - apply Cstep_cset with (c := c); auto.
      now apply mode_access_ok_project_ok.
      now apply project_update_comm_mem.
      now apply mode_alive_project_alive.
    - apply Cstep_enclave with (enc := enc) (c := c); auto.
      apply IHcstep2 with (c1 := c); auto.
    - constructor.
    - apply Cstep_seq_hd with (hd:=hd) (tl:=tl)
                                       (r:=(project_reg r0 is_left))
                                       (m:=(project_mem m0 is_left))
                                       (k:=(project_kill k is_left))
                                       (tr:=(project_trace tr is_left))
                                       (tr':=(project_trace tr' is_left)); auto.
      apply IHcstep2_1 with (c0 := hd); auto.
      (* XXX *)
      admit.
      now apply project_app_trace.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *.
      apply Cstep_if with (e:=e) (c1:=c1) (c2:=c2) (v := (Vnat 1)); auto. discriminate.
      apply IHcstep2 with (c0 := c1); auto.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *.
      apply Cstep_else with (e:=e) (c1:=c1) (c2:=c2) (v := (Vnat 0)); auto.
      apply IHcstep2 with (c0 := c2); auto.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *;
        apply project_merge_inv_reg in H3; apply project_merge_inv_mem in H4;
          destruct_conjs; subst.
      destruct is_left; [destruct n1 | destruct n2].
      1,3: apply Cstep_else with (e := e) (c1 := c1) (c2 := c2) (v := Vnat 0); auto;
        rewrite project_merge_inv_trace; auto.
      apply Cstep_if with (e := e) (c1 := c1) (c2 := c2) (v := Vnat (S n1)); auto.
      discriminate.
      rewrite project_merge_inv_trace; auto.
      apply Cstep_if with (e := e) (c1 := c1) (c2 := c2) (v := Vnat (S n2)); auto.
      discriminate.
      rewrite project_merge_inv_trace; auto.
    - rewrite project_app_trace.
      admit.
    - apply Cstep_while_f with (e := e) (c := c); auto.
      now apply impe2_exp_sound with (is_left := is_left) in H0.
      now apply mode_alive_project_alive.
    - admit.
    - admit.
  Admitted.

  (* XXX: I don't think this is the right phrasing because this would imply
     that if IMP steps to v1 then IMPE takes steps to the pair (v1 | _) *)
 (* Lemma impe2_exp_complete : forall md d e r m K v is_left,
      estep md d (project_ecfg (e, r, m, K) is_left)
            (project_value v is_left) -> estep2 md d (e, r, m, K) v.
  Proof.
    intros.
    remember (project_ecfg (e, r, m, K) is_left) as ecfg.
    remember (project_value v is_left) as v'.
    generalize dependent e.
    induction H; intros; subst.
    - unfold project_ecfg in H; simpl in *; subst.
      destruct v.
      admit.
     

  Qed.*)
       
  
End Adequacy.