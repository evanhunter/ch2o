(* Copyright (c) 2012, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
(** This file collects some general purpose tactics that are used throughout
the development. *)
Require Export Psatz.
Require Export base.

(** We declare hint databases [lia] and [congruence] containing solely the
following hints. These hint database are useful in combination with another
hint database [db] that contain lemmas with premises that should be solved by
[lia] or [congruence]. One can now just say [auto with db,lia]. *)
Hint Extern 1000 => lia : lia.
Hint Extern 1000 => congruence : congruence.

(** The tactic [intuition] expands to [intuition auto with *] by default. This
is rather efficient when having big hint databases, or expensive [Hint Extern]
declarations as the above. *)
Tactic Notation "intuition" := intuition auto.

(** A slightly modified version of Ssreflect's finishing tactic [done]. It
also performs [reflexivity] and does not compute the goal's [hnf] so as to
avoid unfolding setoid equalities. Note that this tactic performs much better
than Coq's [easy] as it does not perform [inversion]. *)
Ltac done :=
  trivial; intros; solve
    [ repeat first
      [ solve [trivial]
      | solve [symmetry; trivial]
      | reflexivity
      | discriminate
      | contradiction
      | split ]
    | match goal with
      H : ¬_ |- _ => solve [destruct H; trivial]
      end ].
Tactic Notation "by" tactic(tac) :=
  tac; done.

Ltac case_match :=
  match goal with
  | H : context [ match ?x with _ => _ end ] |- _ => destruct x eqn:?
  | |- context [ match ?x with _ => _ end ] => destruct x eqn:?
  end.

(** The tactic [clear dependent H1 ... Hn] clears the hypotheses [Hi] and
their dependencies. *)
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) :=
  clear dependent H1; clear dependent H2.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) :=
  clear dependent H1 H2; clear dependent H3.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4) :=
  clear dependent H1 H2 H3; clear dependent H4.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4)
  hyp(H5) := clear dependent H1 H2 H3 H4; clear dependent H5.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4) hyp(H5)
  hyp (H6) := clear dependent H1 H2 H3 H4 H5; clear dependent H6.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4) hyp(H5)
  hyp (H6) hyp(H7) := clear dependent H1 H2 H3 H4 H5 H6; clear dependent H7.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4) hyp(H5)
  hyp (H6) hyp(H7) hyp(H8) :=
  clear dependent H1 H2 H3 H4 H5 H6 H7; clear dependent H8.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4) hyp(H5)
  hyp (H6) hyp(H7) hyp(H8) hyp(H9) :=
  clear dependent H1 H2 H3 H4 H5 H6 H7 H8; clear dependent H9.
Tactic Notation "clear" "dependent" hyp(H1) hyp(H2) hyp(H3) hyp(H4) hyp(H5)
  hyp (H6) hyp(H7) hyp(H8) hyp(H9) hyp(H10) :=
  clear dependent H1 H2 H3 H4 H5 H6 H7 H8 H9; clear dependent H10.

(** The tactic [first_of tac1 tac2] calls [tac1] and then calls [tac2] on the
first subgoal generated by [tac1] *)
Tactic Notation "first_of" tactic3(tac1) "by" tactic3(tac2) :=
     (tac1; [ tac2 ])
  || (tac1; [ tac2 |])
  || (tac1; [ tac2 | | ])
  || (tac1; [ tac2 | | | ])
  || (tac1; [ tac2 | | | | ])
  || (tac1; [ tac2 | | | | | ])
  || (tac1; [ tac2 | | | | | |])
  || (tac1; [ tac2 | | | | | | |])
  || (tac1; [ tac2 | | | | | | | |])
  || (tac1; [ tac2 | | | | | | | | |])
  || (tac1; [ tac2 | | | | | | | | | |])
  || (tac1; [ tac2 | | | | | | | | | | |])
  || (tac1; [ tac2 | | | | | | | | | | | |]).

(** The tactic [is_non_dependent H] determines whether the goal's conclusion or
assumptions depend on [H]. *)
Tactic Notation "is_non_dependent" constr(H) :=
  match goal with
  | _ : context [ H ] |- _ => fail 1
  | |- context [ H ] => fail 1
  | _ => idtac
  end.

(* The tactic [var_eq x y] fails if [x] and [y] are unequal. *)
Ltac var_eq x1 x2 := match x1 with x2 => idtac | _ => fail 1 end.
Ltac var_neq x1 x2 := match x1 with x2 => fail 1 | _ => idtac end.

Tactic Notation "repeat_on_hyps" tactic3(tac) :=
  repeat match goal with H : _ |- _ => progress tac H end.

Ltac block_hyps := repeat_on_hyps (fun H =>
  match type of H with
  | block _ => idtac
  | ?T => change (block T) in H
  end).
Ltac unblock_hyps := unfold block in * |-.

(** The tactic [injection' H] is a variant of injection that introduces the
generated equalities. *)
Ltac injection' H :=
  block_goal; injection H; clear H; intros; unblock_goal.

(** The tactic [simplify_equality] repeatedly substitutes, discriminates,
and injects equalities, and tries to contradict impossible inequalities. *)
Ltac simplify_equality := repeat
  match goal with
  | H : _ ≠ _ |- _ => by destruct H
  | H : _ = _ → False |- _ => by destruct H
  | H : ?x = _ |- _ => subst x
  | H : _ = ?x |- _ => subst x
  | H : _ = _ |- _ => discriminate H
  | H : ?f _ = ?f _ |- _ => apply (injective f) in H
    (* before [injection'] to circumvent bug #2939 in some situations *)
  | H : _ = _ |- _ => injection' H
  | H : ?x = ?x |- _ => clear H
  end.

(** Coq's default [remember] tactic does have an option to name the generated
equality. The following tactic extends [remember] to do so. *)
Tactic Notation "remember" constr(t) "as" "(" ident(x) "," ident(E) ")" :=
  remember t as x;
  match goal with
  | E' : x = _ |- _ => rename E' into E
  end.

(** Given a tactic [tac2] generating a list of terms, [iter tac1 tac2]
runs [tac x] for each element [x] until [tac x] succeeds. If it does not
suceed for any element of the generated list, the whole tactic wil fail. *)
Tactic Notation "iter" tactic(tac) tactic(l) :=
  let rec go l :=
  match l with
  | ?x :: ?l => tac x || go l
  end in go l.

(** Given H : [A_1 → ... → A_n → B] (where each [A_i] is non-dependent), the
tactic [feed tac H tac_by] creates a subgoal for each [A_i] and calls [tac p]
with the generated proof [p] of [B]. *)
Tactic Notation "feed" tactic(tac) constr(H) :=
  let rec go H :=
  let T := type of H in
  lazymatch eval hnf in T with
  | ?T1 → ?T2 =>
    (* Use a separate counter for fresh names to make it more likely that
    the generated name is "fresh" with respect to those generated before
    calling the [feed] tactic. In particular, this hack makes sure that
    tactics like [let H' := fresh in feed (fun p => pose proof p as H') H] do
    not break. *)
    let HT1 := fresh "feed" in assert T1 as HT1;
      [| go (H HT1); clear HT1 ]
  | ?T1 => tac H
  end in go H.

(** The tactic [efeed tac H] is similar to [feed], but it also instantiates
dependent premises of [H] with evars. *)
Tactic Notation "efeed" tactic(tac) constr(H) :=
  let rec go H :=
  let T := type of H in
  lazymatch eval hnf in T with
  | ?T1 → ?T2 =>
    let HT1 := fresh "feed" in assert T1 as HT1;
      [| go (H HT1); clear HT1 ]
  | ?T1 → _ =>
    let e := fresh "feed" in evar (e:T1);
    let e' := eval unfold e in e in
    clear e; go (H e')
  | ?T1 => tac H
  end in go H.

(** The following variants of [pose proof], [specialize], [inversion], and
[destruct], use the [feed] tactic before invoking the actual tactic. *)
Tactic Notation "feed" "pose" "proof" constr(H) "as" ident(H') :=
  feed (fun p => pose proof p as H') H.
Tactic Notation "feed" "pose" "proof" constr(H) :=
  feed (fun p => pose proof p) H.

Tactic Notation "efeed" "pose" "proof" constr(H) "as" ident(H') :=
  efeed (fun p => pose proof p as H') H.
Tactic Notation "efeed" "pose" "proof" constr(H) :=
  efeed (fun p => pose proof p) H.

Tactic Notation "feed" "specialize" hyp(H) :=
  feed (fun p => specialize p) H.
Tactic Notation "efeed" "specialize" hyp(H) :=
  efeed (fun p => specialize p) H.

Tactic Notation "feed" "inversion" constr(H) :=
  feed (fun p => let H':=fresh in pose proof p as H'; inversion H') H.
Tactic Notation "feed" "inversion" constr(H) "as" simple_intropattern(IP) :=
  feed (fun p => let H':=fresh in pose proof p as H'; inversion H' as IP) H.

Tactic Notation "feed" "destruct" constr(H) :=
  feed (fun p => let H':=fresh in pose proof p as H'; destruct H') H.
Tactic Notation "feed" "destruct" constr(H) "as" simple_intropattern(IP) :=
  feed (fun p => let H':=fresh in pose proof p as H'; destruct H' as IP) H.

(** Coq's [firstorder] tactic fails or loops on rather small goals already. In 
particular, on those generated by the tactic [unfold_elem_ofs] to solve
propositions on collections. The [naive_solver] tactic implements an ad-hoc
and incomplete [firstorder]-like solver using Ltac's backtracking mechanism.
The tactic suffers from the following limitations:
- It might leave unresolved evars as Ltac provides no way to detect that.
- To avoid the tactic going into pointless loops, it just does not allow a
  universally quantified hypothesis to be used more than once.
- It does not perform backtracking on instantiation of universally quantified
  assumptions.

Despite these limitations, it works much better than Coq's [firstorder] tactic
for the purposes of this development. This tactic either fails or proves the
goal. *)
Tactic Notation "naive_solver" tactic(tac) :=
  unfold iff, not in *;
  let rec go :=
  repeat match goal with
  (**i intros *)
  | |- ∀ _, _ => intro
  (**i simplification of assumptions *)
  | H : False |- _ => destruct H
  | H : _ ∧ _ |- _ => destruct H
  | H : ∃ _, _  |- _ => destruct H
  (**i simplify and solve equalities *)
  | |- _ => progress simpl in *
  | |- _ => progress simplify_equality
  (**i solve the goal *)
  | |- _ => solve [ eassumption | symmetry; eassumption | reflexivity ]
  (**i operations that generate more subgoals *)
  | |- _ ∧ _ => split
  | H : _ ∨ _ |- _ => destruct H
  (**i solve the goal using the user supplied tactic *)
  | |- _ => solve [tac]
  end;
  (**i use recursion to enable backtracking on the following clauses *)
  match goal with
  (**i instantiations of assumptions *)
  | H : _ → _ |- _ =>
    is_non_dependent H; eapply H; clear H; go
  | H : _ → _ |- _ =>
    is_non_dependent H;
    (**i create subgoals for all premises *)
    efeed (fun p =>
      match type of p with
      | _ ∧ _ =>
        let H' := fresh in pose proof p as H'; destruct H'
      | ∃ _, _ =>
        let H' := fresh in pose proof p as H'; destruct H'
      | _ ∨ _ =>
        let H' := fresh in pose proof p as H'; destruct H'
      | False =>
        let H' := fresh in pose proof p as H'; destruct H'
      end) H;
    (**i solve these subgoals, but clear [H] to avoid loops *)
    clear H; go
  (**i instantiation of the conclusion *)
  | |- ∃ x, _ => eexists; go
  | |- _ ∨ _ => first [left; go | right; go]
  end in go.
Tactic Notation "naive_solver" := naive_solver eauto.