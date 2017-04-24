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
Require Import Coq.Sets.Ensembles.
Import ListNotations.
Require Import Common.
Require Import ImpE.
Require Import ImpE2.

Ltac unfold_cfgs :=
  unfold ccfg_update_reg2 in *;
  unfold ccfg_to_ecfg2 in *;
  unfold ccfg_reg2 in *;
  unfold ccfg_mem2 in *;
  unfold ccfg_com2 in *;
  unfold ecfg_exp2 in *;
  unfold ecfg_reg2 in *;
  unfold ecfg_update_exp2 in *;
  unfold ccfg_update_com2 in *;
  unfold ccfg_update_mem2 in *;
  unfold ccfg_update_mem in *;
  unfold ccfg_update_reg in *;
  unfold ccfg_update_com in *;
  unfold ccfg_to_ecfg in *;
  unfold project_ccfg.

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

  Lemma l2_zero_or_one (n : nat) : n < 2 -> n = 0 \/ n = 1.
  Proof.
    omega.
  Qed.    

  (* XXX: thought I needed this for exp_output_wf, didn't use it. Might still be useful...? *)
  Lemma estep2_deterministic : forall md d e r m v1 v2,
    estep2 md d (e, r, m) v1 ->
    estep2 md d (e, r, m) v2 ->
    v1 = v2.
  Proof.
    intros; revert H0; revert v2.
    induction H; intros; destruct ecfg as [[e' r'] m']; simpl in *; try rewrite H in H0.
    1-3: inversion H0; subst; try discriminate; simpl in H1; congruence.
    inversion H1; subst; try discriminate; simpl in *; congruence.
    - rewrite H in H3; inversion H3; try discriminate; simpl in *;
        assert (e1 = e0) by congruence; assert (e2 = e3) by congruence;
          subst; apply IHestep2_1 in H5; apply IHestep2_2 in H6; congruence.
    - rewrite H in H3; inversion H3; subst; try discriminate; simpl in *.
      assert (e0 = e1) by congruence.
      assert (r0 = r1) by congruence.
      assert (m0 = m1) by congruence.
      subst. apply IHestep2 in H5. assert (l = l0) by congruence; now subst.
  Qed.      

  Lemma project_comm_reg : forall r b x,
      (project_reg r b) x = project_value (r x) b.
  Proof.
    intros; unfold project_reg; destruct (r x); auto.
  Qed.

  Lemma project_comm_mem : forall m b x,
      (project_mem m b) x = project_value (m x) b.
  Proof.
    intros; unfold project_mem; destruct (m x); auto.
  Qed.
  
  (* XXX: this might be a pain to prove with registers as functions. Used below in soundness. *)
  Lemma project_update_comm_reg : forall ccfg x v is_left,
      project_reg (ccfg_update_reg2 ccfg x v) is_left = 
      ccfg_update_reg (project_ccfg ccfg is_left) x (project_value v is_left).
  Proof.
    intros.
    extensionality z.
    unfold project_reg; unfold ccfg_update_reg; unfold ccfg_update_reg2.
    destruct (z =? x).
    - unfold project_value; auto.
    - simpl; now unfold project_reg.
  Qed.

  Lemma project_update_comm_mem : forall ccfg l v is_left,
      project_mem (ccfg_update_mem2 ccfg l v) is_left = 
      ccfg_update_mem (project_ccfg ccfg is_left) l (project_value v is_left).
  Proof.
    intros.
    extensionality z.
    unfold_cfgs; unfold ccfg_update_mem2; unfold project_mem.
    destruct (z =? l).
    - unfold project_value; auto.
    - simpl; now unfold project_mem.
  Qed.

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
    intros.
    induction t1.
    - rewrite app_nil_l; now cbn.
    - cbn; rewrite IHt1; now destruct (event2_to_event a is_left).
  Qed.

  (* Executing a singleton sequence is the same as executing the command *)
  Lemma cstep_seq_singleton : forall md d c r m r' m' t,
      cstep md d (Cseq [c], r, m) (r', m') t ->
      cstep md d (c, r, m) (r', m') t.
    intros.
    inversion H; subst; try discriminate; unfold_cfgs.
    simpl in H3.
    simpl in H2; assert (tl = []) by congruence.
    rewrite H0 in H7. inversion H7; subst; try discriminate.
    rewrite app_nil_r; congruence.    
  Qed.
    
  Lemma contains_nat_project_nat : forall v is_left,
      contains_nat v -> exists n, project_value v is_left = Vnat n.
  Proof.
    intros.
    destruct v.
    - unfold contains_nat in H; destruct H.
      + destruct H; exists x; simpl; congruence.
      + destruct H; destruct H; discriminate.
    - unfold contains_nat in H; destruct H.
      + destruct H; discriminate.
      + destruct H; destruct H.
        destruct is_left; [exists x | exists x0]; simpl; congruence.
  Qed.

  Lemma project_value_apply_op : forall op v1 v2 n1 n2 is_left,
      project_value v1 is_left = Vnat n1 ->
      project_value v2 is_left = Vnat n2 ->
      (project_value (apply_op op v1 v2) is_left) = Vnat (op n1 n2).
  Proof.
  Admitted.
      
  Lemma impe2_exp_sound : forall md d e r m v is_left,
      estep2 md d (e, r, m) v ->
      estep md d (e, project_reg r is_left, project_mem m is_left) (project_value v is_left).
  Proof.
    intros.
    remember (e, r, m) as ecfg.
    generalize dependent e.
    induction H; intros; try rewrite Heqecfg in H; simpl in *; try rewrite H.
    1-3: constructor; simpl; auto.
    - apply Estep_var with (x:=x); auto; subst; apply project_comm_reg.
    - destruct_conjs.
      apply contains_nat_project_nat with (is_left := is_left) in H2; destruct H2.
      apply contains_nat_project_nat with (is_left := is_left) in H3; destruct H3.
      pose (project_value_apply_op op v1 v2 x x0 is_left H2 H3); rewrite e0.
      apply Estep_binop with (e1:=e1) (e2:=e2); simpl; auto;
        [rewrite <- H2; apply (IHestep2_1 e1) | rewrite <- H3; apply (IHestep2_2 e2)];
        rewrite Heqecfg; unfold ecfg_update_exp2; auto.
    - inversion H; subst.
      apply Estep_deref with (e:=e) (l:=l) (m:=project_mem m0 is_left)
                                    (r:=project_reg r0 is_left); simpl; auto.
  Qed.

  Lemma impe2_sound : forall md d c r m r' m' t is_left,
    cstep2 md d (c, r, m) (r', m') t ->
    cstep md d (project_ccfg (c, r, m) is_left)
          (project_reg r' is_left, project_mem m' is_left) (project_trace t is_left).
  Proof.
    intros.
    remember (c, r, m) as ccfg.
    remember (r', m') as cterm.
    generalize dependent r'.
    generalize dependent m'.
    generalize dependent c.
    induction H; intros; try rewrite Heqccfg in H, Heqcterm; simpl in *; inversion Heqcterm; subst.
    - constructor; auto.
    - apply impe2_exp_sound with (is_left:=is_left) in H0.
      apply Cstep_assign with (x:=x) (e:=e) (v := project_value v is_left); auto.
      unfold ccfg_to_ecfg; simpl in *; auto.
      apply project_update_comm_reg.
    - apply impe2_exp_sound with (is_left:=is_left) in H1.
      apply Cstep_declassify with (x:=x) (e:=e) (v :=(project_value v is_left)); auto.
      apply project_update_comm_reg.
    - apply impe2_exp_sound with (is_left:=is_left) in H0.
      apply impe2_exp_sound with (is_left:=is_left) in H1.
      apply Cstep_update with (e1 := e1) (e2 := e2) (l := l) (v := project_value v is_left); auto.
      now apply project_update_comm_mem.
    - apply impe2_exp_sound with (is_left:=is_left) in H0; simpl in *.
      apply Cstep_output with (e := e); auto.
      destruct sl; auto.
    - apply impe2_exp_sound with (is_left:=is_left) in H0; simpl in *.
      apply Cstep_call with (e := e) (c := c); auto.
      apply IHcstep2 with (c1 := c); auto.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *;
        apply project_merge_inv_reg in H3; apply project_merge_inv_mem in H4.
      destruct_conjs; subst.
      destruct is_left;
        [apply Cstep_call with (e:=e) (c:=c1) | apply Cstep_call with (e:=e) (c:=c2)]; auto;
      unfold ccfg_update_com; simpl; rewrite project_merge_inv_trace; auto.
    - apply Cstep_enclave with (enc := enc) (c := c); auto.
      apply IHcstep2 with (c1 := c); auto.
    - apply Cstep_seq_nil; auto. 
    - apply Cstep_seq_hd with (hd:=hd) (tl:=tl)
                                       (r:=(project_reg r0 is_left))
                                       (m:=(project_mem m0 is_left))
                                       (tr:=(project_trace tr is_left))
                                       (tr':=(project_trace tr' is_left)); auto.
      apply IHcstep2_1 with (c0:=hd); auto.
      apply IHcstep2_2 with (c:=Cseq tl); auto.
      admit.
      (* XXX: getting stuck with a weird induction hypothesis... maybe generalizing wrong *)
      now apply project_app_trace.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *.
      apply Cstep_if with (e:=e) (c1:=c1) (c2:=c2); auto.
      apply IHcstep2 with (c0 := c1); auto.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *.
      apply Cstep_else with (e:=e) (c1:=c1) (c2:=c2); auto.
      apply IHcstep2 with (c0 := c2); auto.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *.
      destruct H1; apply l2_zero_or_one in H1; apply l2_zero_or_one in H6.
        apply project_merge_inv_reg in H4; apply project_merge_inv_mem in H5;
          destruct_conjs; unfold cleft in *; unfold cright in *; subst.
        destruct is_left; [destruct H1 | destruct H6]; rewrite H in *.
        1,3: apply Cstep_else with (e := e) (c1 := c1) (c2 := c2).
        7,8: apply Cstep_if with (e := e) (c1 := c1) (c2 := c2).
        all: auto; unfold_cfgs; simpl in *; try rewrite project_merge_inv_trace; auto.
    - rewrite project_app_trace; simpl in *; subst.
      apply Cstep_while_t with (e := e) (c := c)
                                        (r := (project_reg r0 is_left))
                                        (m := (project_mem m0 is_left)); auto.
      now apply impe2_exp_sound with (is_left := is_left) in H0.
      now apply IHcstep2_1 with (c0 := c).
      (* XXX problem with inductive hypothesis *)
      apply IHcstep2_2 with (c0 := (Cwhile e c)); auto.
      admit.
    - apply Cstep_while_f with (e := e) (c := c); auto.
      now apply impe2_exp_sound with (is_left := is_left) in H0.
    - apply impe2_exp_sound with (is_left := is_left) in H0; simpl in *;
        apply project_merge_inv_reg in H4; apply project_merge_inv_mem in H5;
          destruct_conjs; apply l2_zero_or_one in H1; apply l2_zero_or_one in H8;
            unfold cleft in *; unfold cright in *.
      destruct is_left; [destruct H1; rewrite H1 in * | destruct H8; rewrite H8 in *];
        rewrite project_merge_inv_trace; subst; unfold_cfgs; simpl in *.
      1,2: inversion H2; subst; try discriminate.
      3,4: inversion H3; subst; try discriminate.
      1,3: apply Cstep_while_f with (e := e) (c := c); auto.
      all: apply Cstep_while_t with (e := e) (c := c) (r := r0) (m := m0); auto;
        unfold_cfgs; simpl in *;
          assert (c = hd) by congruence; rewrite H; auto;
            assert ([Cwhile e c] = tl) by congruence; subst;
              now apply cstep_seq_singleton in H10.
  Admitted.

  (* XXX: these assumptions are gross, but the semantics become a mess if we
     dont' have them... *)

  Definition contains_lambda (v : val2) :=
    (exists md c, v = VSingle (Vlambda md c)) \/
    (exists md1 c1 md2 c2, v = VPair (Vlambda md1 c1) (Vlambda md2 c2)).
  
  Lemma project_lambda_contains_lambda : forall v md c is_left,
      project_value v is_left = Vlambda md c ->
      contains_lambda v.
  Proof.
  Admitted.
    
  
  Lemma project_nat_contains_nat : forall v n is_left,
      project_value v is_left = Vnat n ->
      contains_nat v.
  Proof.
  Admitted.

  Lemma no_location_pairs : forall v l is_left,
      project_value v is_left = Vloc l ->
      v = VSingle (Vloc l).
  Proof.
  Admitted.
  
  Lemma impe2_exp_complete : forall md d e r m v'i is_left,
      estep md d (e, project_reg r is_left, project_mem m is_left) v'i ->
      exists v', estep2 md d (e, r, m) v' /\ (project_value v' is_left = v'i).
  Proof.
    intros.
    remember (e, project_reg r is_left, project_mem m is_left) as ecfg.
    generalize dependent e.
    induction H; intros; rewrite Heqecfg in H; simpl in *.
    - exists (VSingle (Vnat n)); subst; split; auto; now constructor.
    - exists (VSingle (Vloc l)); subst; split; auto; now constructor.
    - exists (VSingle (Vlambda md c)); subst; split; auto; now constructor.
    - exists (r x); split; auto. rewrite H. apply Estep2_var with (x:=x); auto.
      rewrite Heqecfg in H0; simpl in *. rewrite <- H0.
      now apply project_comm_reg.
    - destruct IHestep1 with (e := e1). rewrite Heqecfg; auto.
      destruct IHestep2 with (e := e2). rewrite Heqecfg; auto.
      destruct_conjs.
      exists (apply_op op x x0); split; auto.
      apply Estep2_binop with (e1:=e1) (e2:=e2); auto.
      split. now apply project_nat_contains_nat in H5.
      now apply project_nat_contains_nat in H4.
      apply project_value_apply_op; auto.
    - assert (r0 = project_reg r is_left) by congruence.
      assert (m0 = project_mem m is_left) by congruence.
      destruct IHestep with (e0 := e). congruence.
      destruct_conjs.
      apply no_location_pairs in H6.
      exists (m l); split.
      apply Estep2_deref with (e := e) (r :=r) (m := m) (l := l); auto.
      congruence.
      rewrite <- H6; auto.
      rewrite <- project_comm_mem; rewrite <- H4; auto.
    Qed.
      
  Lemma impe2_complete : forall md d c r m r'1 m'1 t'1 r'2 m'2 t'2,
      (cstep md d (project_ccfg (c, r, m) true) (r'1, m'1) t'1) /\
      (cstep md d (project_ccfg (c, r, m) false) (r'2, m'2) t'2) ->
      exists r' m' t',
        (cstep2 md d (c, r, m) (r', m') t' /\
        (project_reg r' true) = r'1 /\
        (project_mem m' true) = m'1 /\
        (project_trace t' true) = t'1) /\
        (project_reg r' false) = r'2 /\
        (project_mem m' false) = m'2 /\
        (project_trace t' false) = t'2.
  Proof.
    intros.
    destruct H.
    remember (project_ccfg (c, r, m) true) as ccfg1.
    remember (project_ccfg (c, r, m) false) as ccfg2.
    remember (r'1, m'1) as cterm1.
    remember (r'2, m'2) as cterm2.
    generalize dependent r'1; generalize dependent m'1.
    generalize dependent r'2; generalize dependent m'2.
    generalize dependent c.
    (* Eliminate all of the generated by the induction where the commands don't match *)
    induction H, H0; intros;
      unfold project_ccfg in *;
        rewrite Heqccfg1 in *; rewrite Heqccfg2 in *; simpl in *; subst;
          try discriminate.
    (* Call case is one of the interesting ones because it has a div step *)
    Focus 6.
    - destruct IHcstep with (c0 := c) (m'1 := m') (r'1 := r') (m'2 := m'0) (r'2 := r'0); auto.
      Focus 2.
      (* This case is clearly false *)
      admit.
      admit.
      admit.
  Admitted.
      
        (* XXX: This was all from the old proof of the incorrect statement *)
    (*induction H; intros; try rewrite Heqccfg in H; simpl in *; subst;
      unfold project_ccfg in Heqcterm; simpl in *.
    - exists r; exists m; exists []. repeat split.
      constructor; auto.
      all: congruence.
    - apply impe2_exp_complete in H0; destruct H0; destruct_conjs.
      exists (ccfg_update_reg2 (Cassign x e, r, m) x x0).
      exists m; exists []; repeat split.
      apply Cstep2_assign with (x := x) (e := e) (v := x0); auto.
      rewrite project_update_comm_reg. rewrite H0. unfold project_ccfg; simpl.
      all: congruence.
    - apply impe2_exp_complete in H1; destruct H1; destruct_conjs.
      exists (ccfg_update_reg2 (Cdeclassify x e, r, m) x x0).
      exists m; exists [Decl2 e m]; repeat split.
      apply Cstep2_declassify with (x := x) (v := x0); auto.
      rewrite project_update_comm_reg. rewrite H1. unfold project_ccfg; simpl.
      all: congruence.
    - apply impe2_exp_complete in H1; destruct H1;
        apply impe2_exp_complete in H0; destruct H0; destruct_conjs.
      pose (no_location_pairs x0 l is_left H1).
      exists r; exists (ccfg_update_mem2 (Cupdate e1 e2, r, m) l x); exists []; repeat split.
      apply Cstep2_update with (e1 := e1) (e2 := e2) (l := l) (v := x); auto.
      rewrite <- e; auto.
      congruence.
      rewrite project_update_comm_mem. unfold project_ccfg; simpl; congruence.
    - apply impe2_exp_complete in H0; destruct H0; destruct_conjs.
      exists r; exists m; exists [Mem2 m; Out2 sl x]; repeat split; try congruence.
      apply Cstep2_output with (e := e); auto.
      cbn; now rewrite H0.
    - destruct IHcstep with (c0 := c) (m'i := m') (r'i := r'); auto.
      do 3 destruct H; apply impe2_exp_complete in H0; destruct H0; destruct_conjs.
      destruct x2.
      + exists x; exists x0; exists x1; repeat split; auto.
        apply Cstep2_call with (e := e) (c := c); auto.
        simpl in H5; now subst.
        all: congruence.
      + 
      
      apply no_lambda_pairs in H5; rewrite <- H5; auto.
      all: congruence.
    - destruct IHcstep with (c0 := c) (m'i := m') (r'i := r'); auto.
      do 3 destruct H; destruct_conjs.
      exists x; exists x0; exists x1; repeat split; auto.
      apply Cstep2_enclave with (enc := enc) (c := c); auto.
      all: congruence.
    - exists r; exists m; exists []; repeat split.
      apply Cstep2_seq_nil; auto.
      all: congruence.
    - destruct IHcstep1 with (c := hd) (m'i := m0) (r'i := r0); auto.
      destruct IHcstep2 with (c := Cseq tl) (m'i := m') (r'i := r'); auto.
      admit.
      admit.
    - destruct IHcstep with (c := c1) (m'i := m') (r'i := r'); auto.
      do 2 destruct H; destruct_conjs.
      exists x; exists x0; exists x1; repeat split.
      apply impe2_exp_complete in H0; destruct H0; destruct_conjs.
      all: try congruence.
      destruct x2.
      + apply Cstep2_if with (e := e) (c1 := c1) (c2 := c2); auto.
        unfold ccfg_to_ecfg2; simpl in *.
        rewrite <- H5; auto.
      + 
    - admit.
    - admit.
    - admit.*)
  
End Adequacy.

(*******************************************************************************
*
* SECURITY
*
*******************************************************************************)

Section Security.
  
  Parameter g0: sec_spec.
  Parameter immutable_locs: sec_spec -> set location.
  Definition exp_locs_immutable (e: exp) :=
    forall_subexp e (fun e =>
                       match e with
                       | Eloc n => set_In n (immutable_locs g0)
                       | _ => True
                       end).

  Definition esc_hatch : Type := exp.
  Function escape_hatches_of (t: trace) (m: mem2) d :
    Ensemble esc_hatch := 
    (fun e => exists v mdecl md,
         List.In (Decl e mdecl) t /\
         estep md d (e,reg_init,(project_mem m true)) v
         /\ estep md d (e, reg_init, mdecl) v
         /\ exp_novars e /\ exp_locs_immutable e).
                                                                                        
  Lemma filter_app (f:event -> bool) l1 l2:
    filter f (l1 ++ l2) = filter f l1 ++ filter f l2.
  Proof.
    induction l1; simpl; auto. rewrite IHl1. destruct (f a); auto.
  Qed.
  
  Definition tobs_sec_level (sl: sec_level) : trace -> trace :=
    filter (fun event => match event with
                         | Out sl' v => sec_level_le_compute sl' sl
                         | AEnc c c' enc_equiv => true
                         | ANonEnc c => true
                         | _ => false                           
                         end).

  Lemma tobs_sec_level_app (sl: sec_level) (l l': trace) :
    tobs_sec_level sl l ++ tobs_sec_level sl l' = tobs_sec_level sl (l ++ l').
  Proof.
    unfold tobs_sec_level. now rewrite (filter_app _ l l').
  Qed.

  Definition corresponds (G: context) : Prop :=
    (forall l p bt rt, g0 l = p -> (loc_context G) l = Some (Typ bt p, rt))
    /\ (forall x, (var_context G) x = Some (Typ Tnat (L))).

  Definition mem_sl_ind (m: mem2) (sl: sec_level) :=
    forall l : location,
      sec_level_le (g0 l) sl ->
      (project_mem m true) l = (project_mem m false) l.

  Definition mem_esc_hatch_ind (m: mem2) d H :=
    forall e v,
      exists md,
        In esc_hatch H e ->
        estep md d (e, reg_init, (project_mem m true)) v ->
        estep md d (e, reg_init, (project_mem m false)) v.
  
  Definition secure_prog (sl: sec_level) (d: loc_mode) (c: com) (G: context) : Prop :=
    forall m0 mknown m r' m' t tobs,
      merge_mem m0 mknown m ->
      cstep2 Normal d (c, reg_init2, m) (r', m') t ->
      tobs = project_trace t true ->
      mem_sl_ind m sl ->
      mem_esc_hatch_ind m d (escape_hatches_of (project_trace t true) m d) ->
      tobs_sec_level sl tobs = tobs_sec_level sl (project_trace t false).
End Security.

Section Preservation.
  Definition cterm2_ok (G: context) (d: loc_mode) (m0: mem2) (r: reg2) (m: mem2)
             (H: Ensemble esc_hatch)
  : Prop :=
      (forall x v1 v2 bt p,
          (r x = VPair v1 v2 /\ (var_context G) x = Some (Typ bt p)) -> protected p) 
      /\ (forall l v1 v2 bt p rt,
          (m l = VPair v1 v2 /\ (loc_context G) l = Some (Typ bt p, rt))
          -> protected p)
      /\ mem_sl_ind m0 L
      /\ mem_esc_hatch_ind m0 d H.

  Definition cconfig2_ok (pc: sec_level) (md: mode) (G: context) (d: loc_mode)
             (m0: mem2) (c: com) (r: reg2) (m: mem2) (G': context)
             (H: Ensemble esc_hatch)
    : Prop :=
    com_type pc md G d c G'
    /\ (forall x v1 v2 bt p,
           (r x = VPair v1 v2
            /\ (var_context G) x = Some (Typ bt p))
           -> protected p)
    /\ (forall l v1 v2 bt p rt,
           ((m l) = VPair v1 v2 /\ (loc_context G) (l) = Some (Typ bt p, rt))    
           -> protected p)
    /\ mem_sl_ind m0 L
    /\ mem_esc_hatch_ind m0 d H.

  (* XXX assume that if the value is a location, then the policy on the location *)
  (* is protected by S. This should be fine because we're assuming this for *)
  (* memories that are indistinguishable *)
  Lemma econfig2_locs_protected (e: exp) (m0: mem2):
    forall G d r m v v1 v2 bt bt' p p' q md md' rt e',
      mem_sl_ind m0 L ->
      v = VPair v1 v2 ->
      exp_type md G d e (Typ bt p) ->
      estep2 md d (e,r,m) v ->
      e = Ederef e' ->
      exp_type md G d e' (Typ (Tref (Typ bt' p') md' rt) q) ->
      protected q.
  Proof.
  Admitted.

  Lemma econfig2_pair_protected (c: com) : forall md G d e p r m v v1 v2 bt m0 H,
      v = VPair v1 v2 ->
      exp_type md G d e (Typ bt p) ->
      estep2 md d (e,r,m) v ->
      cterm2_ok G d m0 r m H ->
      protected p.
  Proof.
    intros.
    remember (e,r,m) as ecfg.
    generalize dependent e.
    generalize dependent v1.
    generalize dependent v2.
    generalize dependent p.
    pose H2 as Hestep2.
    induction Hestep2; intros; subst; try discriminate; unfold_cfgs;
      unfold cterm2_ok in H3; destruct_pairs; subst.
     - inversion H5; subst.
       apply (H1 x v1 v2 bt p); split; auto.
     - rewrite H4 in *.
       assert (exists v' v'', v1 = VPair v' v'' \/ v2 = VPair v' v'').
       pose (apply_op_pair op v1 v2) as Hop_pair.
       destruct Hop_pair as [Hop1 Hop2].
       assert (contains_nat v1 /\ contains_nat v2 /\
               (exists v3 v4 : val, apply_op op v1 v2 = VPair v3 v4)).
       split; auto. split; auto. exists v3. exists v0.  auto.
       apply Hop1 in H0. destruct H0. destruct H0. destruct_pairs.
       exists x. exists x0. auto.
       inversion H5; subst; try discriminate.
       destruct H0. destruct H0. destruct H0.
       -- assert (protected p0).
          eapply (IHHestep2_1 Hestep2_1). unfold cterm2_ok; auto.
          apply H0. apply H15. auto.
          now apply (join_protected_l p0 q).
       -- assert (protected q ).
          eapply (IHHestep2_2 Hestep2_2). unfold cterm2_ok; auto.
          apply H0. apply H19. auto.
          now apply (join_protected_r p0 q).
     - inversion Heqecfg; subst.
       inversion H6; subst.
       assert (protected q).
       apply (econfig2_locs_protected (Ederef e) m0 G d r m (m l) v1 v2 bt bt
                                      (sec_level_join p0 q) p0 q md md' rt e); auto.
       apply (join_protected_r p0 q); auto.
  Qed.
  
  Lemma impe2_final_config_preservation (G: context) (d: loc_mode) (m0: mem2) :
    forall G' c r m pc md r' m' t H,
      H = escape_hatches_of (project_trace t true) m0 d ->
      context_wt G d ->
      cconfig2_ok pc md G d m0 c r m G' H ->
      cstep2 md d (c,r,m) (r', m') t ->
      cterm2_ok G' d m0 r' m' H.
  Proof.
    intros G' c r m pc md r' m' t H Heh Hcwt Hcfgok Hcstep.
    generalize dependent G.
    generalize dependent G'.
    generalize dependent r.
    generalize dependent m.
    generalize dependent pc.
    generalize dependent r'.
    generalize dependent m'.
    generalize dependent t.
    generalize dependent m0.
    induction c; unfold cterm2_ok; intros; subst; simpl in *; unfold_cfgs;
      unfold cconfig2_ok in Hcfgok; destruct_pairs; unfold_cfgs.
    (* CSkip *)
    - inversion Hcstep; try discriminate; subst.
        inversion H; try discriminate; subst.
      split; [intros | split; intros]; simpl in *; auto.
      -- now apply H0 in H4.
      -- now apply H1 in H4.
    (* CAssign *)
    - inversion H; try discriminate; subst.
      split; [intros | split; intros]; simpl in *; auto; unfold_cfgs.
      inversion Hcstep; try discriminate; unfold_cfgs; subst.
      inversion H9; subst.
      remember (escape_hatches_of (project_trace [] true) m0 d) as esc_hatches.
      -- destruct (Nat.eq_dec x x0).
         --- rewrite <- (Nat.eqb_eq x x0) in e; rewrite e in H4.
             destruct_pairs.
             assert (cterm2_ok (Cntxt vc lc) d m0 r m' esc_hatches) as Hcterm.
             unfold cterm2_ok; auto.
             pose (econfig2_pair_protected
                     (Cassign x0 e0) md (Cntxt vc lc) d e0 p r m' v0 v1 v2 s m0 esc_hatches
                     H4 H6 H13 Hcterm)
               as Heconfig.
             inversion H5; subst.
             now apply (join_protected_l p pc).
         --- rewrite <- (Nat.eqb_neq x x0) in n. rewrite n in H4.
             now apply H0 in H4.
      -- inversion Hcstep; subst; try discriminate; unfold_cfgs. now apply H1 in H4.
    (* Cdeclassify *)
    - inversion H; try discriminate; subst.
      split; [intros | split; intros]; simpl in *; auto; unfold_cfgs.
      inversion Hcstep; try discriminate; unfold_cfgs; subst.
      inversion H10; subst.
      -- destruct (Nat.eq_dec x x0).
         --- rewrite <- (Nat.eqb_eq x x0) in e; rewrite e in H4.
             destruct_pairs.
             unfold mem_esc_hatch_ind in *.
             unfold escape_hatches_of in *.
             (* XXX If m0 is mem_esc_hatch_ind, that means that all locations to compute e *)
             (* must be VSingle vs in the initial memory. furthermore, they are immutable *)
             (* therefore, they must still be VSingle vs and then e must be a Single *)
             admit.
         --- rewrite <- (Nat.eqb_neq x x0) in n. rewrite n in H4.
             now apply H0 in H4.
      -- inversion Hcstep; subst; try discriminate; unfold_cfgs. now apply H1 in H4.
   (* Cupdate *)
    - inversion H; try discriminate; subst.
      split; [intros | split; intros]; simpl in *; auto; unfold_cfgs;
      inversion Hcstep; try discriminate; unfold_cfgs; subst.
      -- now apply H0 in H4.
      -- unfold_cfgs. inversion H9; subst; destruct_pairs.
         
  Admitted.

  Lemma mem_esc_hatch_ind_trace_app (tr tr' : trace) (m0: mem2) : forall d, 
    mem_esc_hatch_ind m0 d (escape_hatches_of (tr ++ tr') m0 d) ->
    mem_esc_hatch_ind m0 d (escape_hatches_of (tr) m0 d)
    /\ mem_esc_hatch_ind m0 d (escape_hatches_of (tr') m0 d).
  Proof.
  Admitted.
  
  Lemma impe2_type_preservation 
        (G: context) (d: loc_mode) (m0: mem2) :
    forall pc md c r m G' H mdmid cmid rmid mmid rmid' mmid' tmid rfin mfin tfin,
      H = escape_hatches_of (project_trace tfin true) m0 d -> 
      context_wt G d ->
      cconfig2_ok pc md G d m0 c r m G' H ->
        cstep2 mdmid d (cmid, rmid, mmid) (rmid', mmid') tmid
        -> cstep2 md d (c, r, m) (rfin, mfin) tfin
        -> imm_premise cmid mdmid rmid mmid rmid' mmid' tmid
                       c md r m rfin mfin tfin d ->
        exists pcmid Gmid Gmid',
          sec_level_le pc pcmid /\ context_wt Gmid d /\
          cconfig2_ok pcmid mdmid Gmid d m0 cmid rmid mmid Gmid' H.
  Proof.
    intros pc md c r m G' esc_hatches mdmid cmid rmid mmid rmid' mmid' tmid rfin mfin tfin
           Heh HGwt Hccfg2ok HIP.
    revert tfin mfin rfin tmid mmid' rmid' mmid rmid cmid mdmid r m G' Hccfg2ok HGwt HIP Heh.
    induction c; intros; destruct_pairs; inversion H0; try discriminate; subst; unfold_cfgs;
      inversion Hccfg2ok; try discriminate; subst; destruct_pairs;
        inversion H1; try discriminate; subst; unfold_cfgs.
    (* CALL *)
    - exists p. exists Gm. exists Gp. split. now apply sec_level_join_le_l in H10.
      unfold cconfig2_ok; split; auto; unfold_cfgs.
      admit. (* XXX ew contexts *)
      split.
      eapply (call_fxn_typ _ _ _ _ _ _ _ _ _ _ _ _ _ H1 H9 H2).
      admit. (* XXX ew contexts *)
    (* ENCLAVE *)
    - exists pc. exists G. exists G'. split. apply sec_level_le_refl.
      split. apply HGwt.
      inversion Hccfg2ok; unfold_cfgs; subst; try discriminate; destruct_pairs.
      inversion H1; try discriminate; unfold_cfgs; subst. inversion H6; subst.
      inversion H15; subst.
      unfold cconfig2_ok; split; unfold_cfgs; auto.
    (* SEQ1 *)
    - exists pc. exists G. exists g'.
      split. apply sec_level_le_refl.
      split. auto.
      unfold cconfig2_ok; split; unfold_cfgs; auto.
    (* SEQ2 *)
    - exists pc. exists g'. exists G'.
      split. apply sec_level_le_refl.
      split.
      admit. (* XXX context-wt *)
      assert (cconfig2_ok pc md G d m0 c r m g'
                          (escape_hatches_of (project_trace tr' true) m0 d))
        as c_ok.
      unfold cconfig2_ok in *; destruct_pairs.
      split; auto. split; auto. split; auto. split; auto.
      rewrite <- project_trace_app in H7.
      pose (mem_esc_hatch_ind_trace_app (project_trace tr' true) (project_trace tmid true)
                                        m0 d H7); destruct_pairs; auto.
      assert (cterm2_ok g' d m0 rmid mmid (escape_hatches_of (project_trace tr' true) m0 d))
        as cterm2ok.
      apply (impe2_final_config_preservation G d m0 g' c r m pc md rmid mmid tr'); auto.
      unfold cconfig2_ok in *; unfold cterm2_ok in *; destruct_pairs; unfold_cfgs; auto.
    (* IF *)
    - exists pc'. exists G. exists G'.
      split. now apply (sec_level_join_le_l pc p pc') in H19.
      split; unfold cconfig2_ok; auto.
    (* ELSE *)
    - exists pc'. exists G. exists G'.
      split. now apply (sec_level_join_le_l pc p pc') in H18.
      split; unfold cconfig2_ok; auto.
    (* WHILE1 *)
    - exists pc'. exists G'. exists G'.
      split. now apply (sec_level_join_le_l pc p pc') in H17.
      split; unfold cconfig2_ok; auto.
    (* WHILE2 *)
    - exists pc. exists G'. exists G'.
      split. now apply sec_level_le_refl.
      split; auto.
      assert (cconfig2_ok pc' md G' d m0 c r m G'
                          (escape_hatches_of (project_trace (tr') true) m0 d)).
      unfold cconfig2_ok; split; unfold_cfgs; auto.
      split; auto. split; auto. split; auto. 
      rewrite <- project_trace_app in H7.
      pose (mem_esc_hatch_ind_trace_app (project_trace tr' true) (project_trace tmid true)
                                        m0 d H7); destruct_pairs; auto.
      assert (cterm2_ok G' d m0 rmid mmid (escape_hatches_of (project_trace tr' true) m0 d))
        as cterm2ok.
      apply (impe2_final_config_preservation G' d m0 G' c r m pc' md rmid mmid tr'); auto.
      unfold cconfig2_ok in *; unfold cterm2_ok in *; destruct_pairs; unfold_cfgs; auto.
  Admitted.
End Preservation.

(***********************************)

Section Guarantees.
  Lemma protected_typ_no_obs_output : forall pc md d G c G' r m r' m' tr,
    com_type pc md G d c G' ->
    protected pc ->
    cstep md d (c,r,m) (r',m') tr ->
    tobs_sec_level L tr = [].
  Proof.
    intros.
  Admitted.

  Lemma protected_while_no_obs_output : forall pc pc' md d G e c r m r' m' tr,
      com_type pc md G d (Cwhile e c) G ->
      com_type pc' md G d c G ->
      protected pc' ->
      cstep md d (Cseq [c; Cwhile e c],r,m) (r',m') tr ->
      tobs_sec_level L tr = [].
  Proof.
    intros.
  Admitted.

  Lemma esc_hatches_union (t t' : trace) : forall md d,
      Same_set esc_hatch
               (Union esc_hatch (escape_hatches_of t md d) (escape_hatches_of t' md d))
               (escape_hatches_of (t ++ t') md d).
  Proof.
    intros. unfold Same_set; split;
    induction t, t'; simpl; unfold escape_hatches_of; simpl;
      unfold Included; unfold In; intros.
    - destruct H; unfold In in *; destruct H; destruct H; destruct H; destruct_pairs; omega.
    - destruct H; unfold In in *; destruct H; destruct H; destruct H; destruct_pairs;
        [omega | exists x0; exists x1; exists x2; auto].
    - destruct H; unfold In in *; destruct H; destruct H; destruct H; destruct_pairs;
        [exists x0; exists x1; exists x2; rewrite app_nil_r; auto | omega].
    - 
  Admitted.

  Lemma cconfig2_ok_smaller_EH : forall pc md G d m0 c r m G' EH1 EH2,
    cconfig2_ok pc md G d m0 c r m G' (Union esc_hatch EH1 EH2) ->
    cconfig2_ok pc md G d m0 c r m G' EH1
    /\ cconfig2_ok pc md G d m0 c r m G' EH2.
  Proof.
    intros.
    unfold cconfig2_ok in *; destruct_pairs; repeat (split; auto).
    unfold mem_esc_hatch_ind in *.
  Admitted.

  Lemma esc_hatches_union_eq  (t t' : trace) : forall md d,
       (Union esc_hatch (escape_hatches_of t md d) (escape_hatches_of t' md d)) = 
       (escape_hatches_of (t ++ t') md d).
  Proof.
    intros.
    pose (esc_hatches_union t t' md d).
    apply Extensionality_Ensembles in s; auto.
  Qed.
  
  Lemma config2_ok_implies_obs_equal (m: mem2) (c: com) (t: trace2) :
    forall pc md G d m0 r G' r' m',
      context_wt G d ->
      cconfig2_ok pc md G d m0 c r m G'
                  (escape_hatches_of (project_trace t true) m0 d) ->
      cstep2 md d (c,r,m) (r',m') t ->
      tobs_sec_level L (project_trace t true) = tobs_sec_level L (project_trace t false).
  Proof.
    intros pc md G d m0 r G' r' m' HGwt Hccfg2ok Hcstep2.
    remember (c,r,m) as ccfg.
    generalize dependent c.
    generalize dependent r.
    generalize dependent m.
    generalize dependent pc.
    generalize dependent G'.
    generalize dependent G.
    pose Hcstep2 as Hcstep.
    induction Hcstep; intros; subst; simpl in *; auto; repeat unfold_cfgs; subst.
    (* OUTPUT *)
    - unfold sec_level_le_compute. destruct sl; auto.
      destruct v; simpl; auto.
      inversion Hccfg2ok; destruct_pairs; unfold_cfgs; subst; auto; try discriminate.
      inversion H; unfold_cfgs; try discriminate; subst; auto.
      remember (VPair v v0) as vpair.
      pose (escape_hatches_of [Mem (project_mem m true); Out L (project_value vpair true)]
                              m0 d) as EH.
      assert (cterm2_ok G' d m0 r m EH) as Hctermok; unfold cterm2_ok; auto.
      assert (protected p) by apply (econfig2_pair_protected
                                          (Coutput e L) md G' d e p r m vpair v v0 s m0
                                          EH Heqvpair H11 H0 Hctermok).
      pose (sec_level_join_ge p pc); destruct_pairs.
      apply (sec_level_le_trans p (sec_level_join p pc) L) in H13; auto.
      destruct p; inversion H5; inversion H13.
    (* CALL *)
    - remember (escape_hatches_of (project_trace tr true) m0 d) as EH.
      assert (imm_premise c md r m r'0 m'0 tr
                          (Ccall e) md r m r'0 m'0 tr d)
        as HIP by now apply IPcall.
      pose (impe2_type_preservation G d m0 pc md (Ccall e) r m G' EH
                                    md c r m r'0 m'0 tr r'0 m'0 tr 
                                    HeqEH HGwt Hccfg2ok
                                    Hcstep Hcstep2 HIP)
        as Lemma6.
      destruct Lemma6 as [pcmid [Gmid [Gmid' Lemma6]]]; destruct_pairs; subst.
      apply (IHHcstep Hcstep Gmid H1 Gmid' pcmid m r c H2); auto.
    (* CALL-DIV *)
    - remember (VPair (Vlambda md c1) (Vlambda md c2)) as v.
      inversion Hccfg2ok; destruct_pairs; unfold_cfgs; subst; auto; try discriminate.
      inversion H; unfold_cfgs; try discriminate; subst; auto.
      remember (escape_hatches_of (project_trace (merge_trace (t1, t2)) true) m0 d) as EH.
      assert (protected q) as Hqprotected.
      eapply econfig2_pair_protected in H10; auto. apply H0.
      assert (cterm2_ok G d m0 r m EH) by now unfold cterm2_ok. apply H9.
      assert (protected (sec_level_join pc q)) as Hpcqprotected
          by apply (join_protected_r pc q Hqprotected).
      inversion Hpcqprotected; rewrite Hpcqprotected in H11.
      assert (protected p) as Hpprotected.
      unfold protected. unfold sec_level_le in H11; destruct p; intuition.
      clear H11 H14.
      assert (com_type p md Gm d c1 Gp /\ com_type p md Gm d c2 Gp).
      eapply call_div_fxn_typ. apply H. apply H10. apply H0.
      destruct_pairs.
      assert (tobs_sec_level L t1 = []) as t1_empty.
      eapply protected_typ_no_obs_output in H1; auto.
      apply H9; auto. auto.
      assert (tobs_sec_level L t2 = []) as t2_empty.
      eapply protected_typ_no_obs_output in H2; auto.
      apply H11; auto. auto.
      pose (project_merge_inv_trace t1 t2 true) as Ht1; simpl in *.
      pose (project_merge_inv_trace t1 t2 false) as Ht2; simpl in *.
      now rewrite Ht1, Ht2, t1_empty, t2_empty.
    (* ENCLAVE *)
    - remember (escape_hatches_of (project_trace tr true) m0 d) as EH.
      assert (imm_premise c (Encl enc) r m r'0 m'0 tr
                          (Cenclave enc c) Normal r m r'0 m'0 tr d)
        as HIP by now apply IPencl.
      pose (impe2_type_preservation G d m0 pc Normal (Cenclave enc c) r m G' EH
                                    (Encl enc) c r m r'0 m'0 tr _ _ _ 
                                    HeqEH HGwt Hccfg2ok Hcstep Hcstep2 HIP) as Lemma6.
      destruct Lemma6 as [pcmid [Gmid [Gmid' Lemma6]]]; destruct_pairs; subst.
      apply (IHHcstep Hcstep Gmid H0 Gmid' pcmid m r c H1); auto.
   (* SEQ *)
    - remember (escape_hatches_of (project_trace tr true) m0 d) as EH1.
      remember (escape_hatches_of (project_trace tr' true) m0 d) as EH2.
      remember (Union esc_hatch (escape_hatches_of (project_trace tr true) m0 d)
                      (escape_hatches_of (project_trace tr' true) m0 d)) as EHall.
      assert (EHall = (escape_hatches_of (project_trace (tr ++ tr') true) m0 d))
        as EHapp.
      rewrite <- project_trace_app. rewrite HeqEHall. apply esc_hatches_union_eq.
      
      assert (imm_premise hd md r0 m1 r m tr
                          (Cseq (hd::tl)) md r0 m1 r'0 m'0 (tr++tr') d)
        as HIP1 by apply (IPseq1 _ _ _ _ _ _ _ _ _ _ _ _ Hcstep1 Hcstep3 Hcstep2).
      rewrite <- EHapp in *.
      pose (impe2_type_preservation G d m0 pc md (Cseq (hd::tl)) r0 m1 G' EHall
                                    md hd r0 m1 r m tr _ _ _ 
                                    EHapp HGwt Hccfg2ok Hcstep1 Hcstep2 HIP1) as Lemma61.

      assert (imm_premise (Cseq tl) md r m r'0 m'0 tr'
                          (Cseq (hd::tl)) md r0 m1 r'0 m'0 (tr++tr') d)
        as HIP2 by apply (IPseq2 _ _ _ _ _ _ _ _ _ _ _ _ Hcstep1 Hcstep3 Hcstep2).
      pose (impe2_type_preservation G d m0 pc md (Cseq (hd::tl)) r0 m1 G' EHall
                                    md (Cseq tl) r m r'0 m'0 tr' _ _ _
                                    EHapp HGwt Hccfg2ok Hcstep3 Hcstep2 HIP2)
        as Lemma62.

      destruct Lemma61 as [pcmid1 [Gmid1 [Gmid1' Lemma6]]]; destruct_pairs; subst.
      destruct Lemma62 as [pcmid2 [Gmid2 [Gmid2' Lemma6]]]; destruct_pairs; subst.
      assert (cconfig2_ok pcmid1 md Gmid1 d m0 hd r0 m1 Gmid1'
                          (escape_hatches_of (project_trace tr true) m0 d)) as seq1OK
          by now apply cconfig2_ok_smaller_EH in H1.
      assert (cconfig2_ok pcmid2 md Gmid2 d m0 (Cseq tl) r m Gmid2'
                          (escape_hatches_of (project_trace tr' true) m0 d)) as seq2OK
          by now apply cconfig2_ok_smaller_EH in H4.
      pose (IHHcstep1 Hcstep1 Gmid1 H0 Gmid1' pcmid1 m1 r0 hd seq1OK) as tr_same.
      pose (IHHcstep2 Hcstep3 Gmid2 H3 Gmid2' pcmid2 m r (Cseq tl) seq2OK) as tr'_same.
      rewrite <- project_trace_app.
      rewrite <- tobs_sec_level_app.
      rewrite tr'_same, tr_same; auto.
      rewrite tobs_sec_level_app. rewrite project_trace_app; auto.
    (* IF *)
    -  remember (escape_hatches_of (project_trace tr true) m0 d) as EH.
       assert (imm_premise c1 md r m r'0 m'0 tr
                           (Cif e c1 c2) md r m r'0 m'0 tr d)
         as HIP by apply (IPif  _ _ _ _ _ _ _ _ _ _ H0 Hcstep Hcstep2 Hcstep2).
       pose (impe2_type_preservation G d m0 pc md (Cif e c1 c2) r m G' EH
                                     md c1 r m r'0 m'0 tr _ _ _
                                     HeqEH HGwt Hccfg2ok Hcstep Hcstep2 HIP) as Lemma6.
       destruct Lemma6 as [pcmid [Gmid [Gmid' Lemma6]]]; destruct_pairs; subst.
       apply (IHHcstep Hcstep Gmid H1 Gmid' pcmid m r c1 H2); auto.
    (* ELSE *)
    -  remember (escape_hatches_of (project_trace tr true) m0 d) as EH.
       assert (imm_premise c2 md r m r'0 m'0 tr
                           (Cif e c1 c2) md r m r'0 m'0 tr d)
         as HIP by apply (IPelse _ _ _ _ _ _ _ _ _ _ H0 Hcstep Hcstep2).
       pose (impe2_type_preservation G d m0 pc md (Cif e c1 c2) r m G' EH
                                     md c2 r m r'0 m'0 tr _ _ _
                                     HeqEH HGwt Hccfg2ok Hcstep Hcstep2 HIP) as Lemma6.
       destruct Lemma6 as [pcmid [Gmid [Gmid' Lemma6]]]; destruct_pairs; subst.
       apply (IHHcstep Hcstep Gmid H1 Gmid' pcmid m r c2 H2); auto.
    (* IFELSE-DIV *)
    - remember (VPair (Vnat n1) (Vnat n2)) as v.
      inversion Hccfg2ok; destruct_pairs; unfold_cfgs; subst; auto; try discriminate.
      inversion H; unfold_cfgs; try discriminate; subst; auto.
      remember (escape_hatches_of (project_trace (merge_trace (t1, t2)) true) m0 d) as EH.
      assert (protected p) as Hqprotected.
      eapply econfig2_pair_protected in H20; auto. apply H0.
      assert (cterm2_ok G d m0 r m EH) by now unfold cterm2_ok. apply H11.
      assert (protected (sec_level_join pc p)) by now apply (join_protected_r pc p).
      inversion H11; rewrite H11 in H22.
      assert (protected pc') as Hpc'protected.
      unfold protected. unfold sec_level_le in H22. destruct pc'; intuition.
      assert (tobs_sec_level L t1 = [] /\ tobs_sec_level L t2 = []).
      destruct n1, n2; simpl in *;
        eapply protected_typ_no_obs_output in H2;
        eapply protected_typ_no_obs_output in H3;
        try apply H14; try apply H15; auto.
      destruct_pairs.
      pose (project_merge_inv_trace t1 t2 true) as Ht1; simpl in *.
      pose (project_merge_inv_trace t1 t2 false) as Ht2; simpl in *.
      now rewrite Ht1, Ht2, H12, H16.
    (* WHILE *)
    - remember (escape_hatches_of (project_trace tr true) m0 d) as EH1.
      remember (escape_hatches_of (project_trace tr' true) m0 d) as EH2.
      remember (Union esc_hatch (escape_hatches_of (project_trace tr true) m0 d)
                      (escape_hatches_of (project_trace tr' true) m0 d)) as EHall.
      assert (EHall = (escape_hatches_of (project_trace (tr ++ tr') true) m0 d))
        as EHapp.
      rewrite <- project_trace_app. rewrite HeqEHall. apply esc_hatches_union_eq.
      
      assert (imm_premise c md r0 m1 r m tr
                          (Cwhile e c) md r0 m1 r'0 m'0 (tr++tr') d)
        as HIP1 by apply (IPwhilet1 _ _ _ _ _ _ _ _ _ _ _ _ H0 Hcstep1 Hcstep3 Hcstep2).
      rewrite <- EHapp in *.
      pose (impe2_type_preservation G d m0 pc md (Cwhile e c) r0 m1 G' EHall
                                    md c r0 m1 r m tr _ _ _ 
                                    EHapp HGwt Hccfg2ok Hcstep1 Hcstep2 HIP1) as Lemma61.

      assert (imm_premise (Cwhile e c) md r m r'0 m'0 tr'
                          (Cwhile e c) md r0 m1 r'0 m'0 (tr++tr') d)
        as HIP2 by apply (IPwhilet2 _ _ _ _ _ _ _ _ _ _ _ _ H0 Hcstep1 Hcstep3 Hcstep2).
      pose (impe2_type_preservation G d m0 pc md (Cwhile e c) r0 m1 G' EHall
                                    md (Cwhile e c) r m r'0 m'0 tr' _ _ _
                                    EHapp HGwt Hccfg2ok Hcstep3 Hcstep2 HIP2)
        as Lemma62.

      destruct Lemma61 as [pcmid1 [Gmid1 [Gmid1' Lemma6]]]; destruct_pairs; subst.
      destruct Lemma62 as [pcmid2 [Gmid2 [Gmid2' Lemma6]]]; destruct_pairs; subst.
      assert (cconfig2_ok pcmid1 md Gmid1 d m0 c r0 m1 Gmid1'
                          (escape_hatches_of (project_trace tr true) m0 d)) as seq1OK
          by now apply cconfig2_ok_smaller_EH in H2.
      assert (cconfig2_ok pcmid2 md Gmid2 d m0 (Cwhile e c) r m Gmid2'
                          (escape_hatches_of (project_trace tr' true) m0 d)) as seq2OK
          by now apply cconfig2_ok_smaller_EH in H5.
      pose (IHHcstep1 Hcstep1 Gmid1 H1 Gmid1' pcmid1 m1 r0 c seq1OK) as tr_same.
      pose (IHHcstep2 Hcstep3 Gmid2 H4 Gmid2' pcmid2 m r (Cwhile e c) seq2OK) as tr'_same.
      rewrite <- project_trace_app.
      rewrite <- tobs_sec_level_app.
      rewrite tr'_same, tr_same; auto.
      rewrite tobs_sec_level_app. rewrite project_trace_app; auto.
    (* WHILE-DIV *)
    - remember (VPair (Vnat n1) (Vnat n2)) as v.
      inversion Hccfg2ok; destruct_pairs; unfold_cfgs; subst; auto; try discriminate.
      inversion H; unfold_cfgs; try discriminate; subst; auto.
      remember (escape_hatches_of (project_trace (merge_trace (t1, t2)) true) m0 d) as EH.
      assert (protected p) as Hqprotected.
      eapply econfig2_pair_protected in H13; auto. apply H0.
      assert (cterm2_ok G' d m0 r m EH) by now unfold cterm2_ok. apply H11.
      assert (protected (sec_level_join pc p)) by now apply (join_protected_r pc p).
      inversion H11; rewrite H11 in H19.
      assert (protected pc') as Hpc'protected.
      unfold protected. unfold sec_level_le in H19. destruct pc'; intuition.

      assert (com_type pc' md G' d Cskip G') as skip_typ by apply CTskip.
      assert (com_type pc md G' d (Cseq [c; Cwhile e c]) G') as seq_type.
      assert (com_type pc md G' d c G') as c_typ.
      apply (subsumption pc' pc md d G' c) in H14; auto.
      destruct pc; simpl in *; auto.
      eapply Tseq. apply c_typ.
      eapply Tseq. apply H.
      eapply Tseqnil.
      assert (tobs_sec_level L t1 = [] /\ tobs_sec_level L t2 = []).
      destruct n1, n2; simpl in *.
      -- eapply protected_typ_no_obs_output in H2; auto. 
         eapply protected_typ_no_obs_output in H3; auto.
         apply skip_typ. auto.
         apply skip_typ. auto.
      -- eapply protected_typ_no_obs_output in H2; auto. 
         eapply protected_while_no_obs_output in H3; auto.
         apply H. apply H14. auto.
         apply skip_typ. auto.
      -- eapply protected_while_no_obs_output in H2; auto.
         eapply protected_typ_no_obs_output in H3; auto.
         apply skip_typ. auto.
         apply H. apply H14. auto.
      -- eapply protected_while_no_obs_output in H2; auto.
         eapply protected_while_no_obs_output in H3; auto.
         apply H. apply H14; auto.
         auto. apply H. apply H14. auto.
      -- destruct_pairs.
         pose (project_merge_inv_trace t1 t2 true) as Ht1; simpl in *.
         pose (project_merge_inv_trace t1 t2 false) as Ht2; simpl in *.
         now rewrite Ht1, Ht2, H12, H16.
  Qed.
      
  Lemma diff_loc_protected : forall m l,
      mem_sl_ind m L ->
      (project_mem m true) l <> (project_mem m false) l ->
      protected (g0 l).
  Proof.
  Admitted.

  Lemma vpair_iff_diff : forall m1 m2 m v1 v2 l,
      merge_mem m1 m2 m ->
      m l = VPair v1 v2 <-> m1 l <> m2 l.
  Proof.
  Admitted.
  
  Lemma secure_passive : forall G G' d c,
    well_formed_spec g0 ->
    corresponds G ->
    context_wt G d ->
    com_type L Normal G d c G' ->
    secure_prog L d c G.
  Proof.
    unfold secure_prog.
    intros G G' d c Hg0wf Hcorr HGwt Hcomtype
           m0 mknown m r' m' t tobs Hmmerge
           Hcstep2 Htobs Hind Hesc.
    rewrite Htobs.
    apply (config2_ok_implies_obs_equal m c t (L) Normal G d
                     m reg_init2 G' r' m'); auto.
    unfold cconfig2_ok; split; unfold_cfgs; auto.
    split; intros; destruct_pairs.
    - inversion H.
    - split; intros; destruct_pairs.
      -- unfold corresponds in Hcorr; destruct_pairs.
         unfold well_formed_spec in Hg0wf.
         pose (Hg0wf l) as Hgwf; destruct Hgwf; destruct_pairs.
         pose H3 as Hg0. apply (H1 l x bt rt) in Hg0.
         rewrite H0 in Hg0. inversion Hg0; subst.
         apply (diff_loc_protected m l); auto.
         apply (vpair_iff_diff m0 mknown m v1 v2 l) in H; auto.
         apply project_merge_inv_mem in Hmmerge; destruct_pairs; subst; auto.
      -- split; intros; auto.
  Qed.
         
(*
  Lemma secure_n_chaos : forall g G G' K' d c,
      well_formed_spec g ->
      corresponds G g ->
      context_wt G d ->
      com_type (LevelP L) Normal G nil nil d c G' K' ->
      secure_prog L g cstep_n_chaos estep c.
  Proof.
  Admitted.
*)       
End Guarantees.

