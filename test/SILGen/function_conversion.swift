// RUN: %target-swift-frontend -emit-silgen %s | %FileCheck %s

// Check SILGen against various FunctionConversionExprs emitted by Sema.

// ==== Representation conversions

// CHECK-LABEL: sil hidden @_TF19function_conversion7cToFuncFcSiSiFSiSi : $@convention(thin) (@convention(c) (Int) -> Int) -> @owned @callee_owned (Int) -> Int
// CHECK:         [[THUNK:%.*]] = function_ref @_TTRXFtCc_dSi_dSi_XFo_dSi_dSi_
// CHECK:         [[FUNC:%.*]] = partial_apply [[THUNK]](%0)
// CHECK:         return [[FUNC]]
func cToFunc(_ arg: @escaping @convention(c) (Int) -> Int) -> (Int) -> Int {
  return arg
}

// CHECK-LABEL: sil hidden @_TF19function_conversion8cToBlockFcSiSibSiSi : $@convention(thin) (@convention(c) (Int) -> Int) -> @owned @convention(block) (Int) -> Int
// CHECK:         [[BLOCK_STORAGE:%.*]] = alloc_stack $@block_storage
// CHECK:         [[BLOCK:%.*]] = init_block_storage_header [[BLOCK_STORAGE]]
// CHECK:         [[COPY:%.*]] = copy_block [[BLOCK]] : $@convention(block) (Int) -> Int
// CHECK:         return [[COPY]]
func cToBlock(_ arg: @escaping @convention(c) (Int) -> Int) -> @convention(block) (Int) -> Int {
  return arg
}

// ==== Throws variance

// CHECK-LABEL: sil hidden @_TF19function_conversion12funcToThrowsFFT_T_FzT_T_ : $@convention(thin) (@owned @callee_owned () -> ()) -> @owned @callee_owned () -> @error Error
// CHECK: bb0([[ARG:%.*]] : $@callee_owned () -> ()):
// CHECK:   [[ARG_COPY:%.*]] = copy_value [[ARG]]
// CHECK:   [[FUNC:%.*]] = convert_function [[ARG_COPY]] : $@callee_owned () -> () to $@callee_owned () -> @error Error
// CHECK:   destroy_value [[ARG]]
// CHECK:   return [[FUNC]]
// CHECK: } // end sil function '_TF19function_conversion12funcToThrowsFFT_T_FzT_T_'
func funcToThrows(_ x: @escaping () -> ()) -> () throws -> () {
  return x
}

// CHECK-LABEL: sil hidden @_TF19function_conversion12thinToThrowsFXfT_T_XfzT_T_ : $@convention(thin) (@convention(thin) () -> ()) -> @convention(thin) () -> @error Error
// CHECK:         [[FUNC:%.*]] = convert_function %0 : $@convention(thin) () -> () to $@convention(thin) () -> @error Error
// CHECK:         return [[FUNC]] : $@convention(thin) () -> @error Error
func thinToThrows(_ x: @escaping @convention(thin) () -> ()) -> @convention(thin) () throws -> () {
  return x
}

// FIXME: triggers an assert because we always do a thin to thick conversion on DeclRefExprs
/*
func thinFunc() {}

func thinToThrows() {
  let _: @convention(thin) () -> () = thinFunc
}
*/

// ==== Class downcasts and upcasts

class Feral {}
class Domesticated : Feral {}

// CHECK-LABEL: sil hidden @_TF19function_conversion12funcToUpcastFFT_CS_12DomesticatedFT_CS_5Feral : $@convention(thin) (@owned @callee_owned () -> @owned Domesticated) -> @owned @callee_owned () -> @owned Feral {
// CHECK: bb0([[ARG:%.*]] : $@callee_owned () -> @owned Domesticated):
// CHECK:   [[ARG_COPY:%.*]] = copy_value [[ARG]]
// CHECK:   [[FUNC:%.*]] = convert_function [[ARG_COPY]] : $@callee_owned () -> @owned Domesticated to $@callee_owned () -> @owned Feral
// CHECK:   destroy_value [[ARG]]
// CHECK:   return [[FUNC]]
// CHECK: } // end sil function '_TF19function_conversion12funcToUpcastFFT_CS_12DomesticatedFT_CS_5Feral'
func funcToUpcast(_ x: @escaping () -> Domesticated) -> () -> Feral {
  return x
}

// CHECK-LABEL: sil hidden @_TF19function_conversion12funcToUpcastFFCS_5FeralT_FCS_12DomesticatedT_ : $@convention(thin) (@owned @callee_owned (@owned Feral) -> ()) -> @owned @callee_owned (@owned Domesticated) -> ()
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[ARG_COPY:%.*]] = copy_value [[ARG]]
// CHECK:   [[FUNC:%.*]] = convert_function [[ARG_COPY]] : $@callee_owned (@owned Feral) -> () to $@callee_owned (@owned Domesticated) -> (){{.*}}
// CHECK:   destroy_value [[ARG]]
// CHECK:   return [[FUNC]]
func funcToUpcast(_ x: @escaping (Feral) -> ()) -> (Domesticated) -> () {
  return x
}

// ==== Optionals

struct Trivial {
  let n: Int8
}

class C {
  let n: Int8

  init(n: Int8) {
    self.n = n
  }
}

struct Loadable {
  let c: C

  var n: Int8 {
    return c.n
  }

  init(n: Int8) {
    c = C(n: n)
  }
}

struct AddrOnly {
  let a: Any

  var n: Int8 {
    return a as! Int8
  }

  init(n: Int8) {
    a = n
  }
}

// CHECK-LABEL: sil hidden @_TF19function_conversion19convOptionalTrivialFFGSqVS_7Trivial_S0_T_
func convOptionalTrivial(_ t1: @escaping (Trivial?) -> Trivial) {
// CHECK:         function_ref @_TTRXFo_dGSqV19function_conversion7Trivial__dS0__XFo_dS0__dGSqS0___
// CHECK:         partial_apply
  let _: (Trivial) -> Trivial? = t1

// CHECK:         function_ref @_TTRXFo_dGSqV19function_conversion7Trivial__dS0__XFo_dGSqS0___dGSqS0___
// CHECK:         partial_apply
  let _: (Trivial!) -> Trivial? = t1
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqV19function_conversion7Trivial__dS0__XFo_dS0__dGSqS0___ : $@convention(thin) (Trivial, @owned @callee_owned (Optional<Trivial>) -> Trivial) -> Optional<Trivial>
// CHECK:         enum $Optional<Trivial>
// CHECK-NEXT:    apply %1(%2)
// CHECK-NEXT:    enum $Optional<Trivial>
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqV19function_conversion7Trivial__dS0__XFo_dGSqS0___dGSqS0___ : $@convention(thin) (Optional<Trivial>, @owned @callee_owned (Optional<Trivial>) -> Trivial) -> Optional<Trivial>
// CHECK:         apply %1(%0)
// CHECK-NEXT:    enum $Optional<Trivial>
// CHECK-NEXT:    return

// CHECK-LABEL: sil hidden @_TF19function_conversion20convOptionalLoadableFFGSqVS_8Loadable_S0_T_
func convOptionalLoadable(_ l1: @escaping (Loadable?) -> Loadable) {
// CHECK:         function_ref @_TTRXFo_oGSqV19function_conversion8Loadable__oS0__XFo_oS0__oGSqS0___
// CHECK:         partial_apply
  let _: (Loadable) -> Loadable? = l1

// CHECK:         function_ref @_TTRXFo_oGSqV19function_conversion8Loadable__oS0__XFo_oGSqS0___oGSqS0___
// CHECK:         partial_apply
  let _: (Loadable!) -> Loadable? = l1
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_oGSqV19function_conversion8Loadable__oS0__XFo_oGSqS0___oGSqS0___ : $@convention(thin) (@owned Optional<Loadable>, @owned @callee_owned (@owned Optional<Loadable>) -> @owned Loadable) -> @owned Optional<Loadable>
// CHECK:         apply %1(%0)
// CHECK-NEXT:    enum $Optional<Loadable>
// CHECK-NEXT:    return

// CHECK-LABEL: sil hidden @_TF19function_conversion20convOptionalAddrOnlyFFGSqVS_8AddrOnly_S0_T_
func convOptionalAddrOnly(_ a1: @escaping (AddrOnly?) -> AddrOnly) {
// CHECK:         function_ref @_TTRXFo_iGSqV19function_conversion8AddrOnly__iS0__XFo_iGSqS0___iGSqS0___
// CHECK:         partial_apply
  let _: (AddrOnly?) -> AddrOnly? = a1

// CHECK:         function_ref @_TTRXFo_iGSqV19function_conversion8AddrOnly__iS0__XFo_iGSqS0___iGSqS0___
// CHECK:         partial_apply
  let _: (AddrOnly!) -> AddrOnly? = a1
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iGSqV19function_conversion8AddrOnly__iS0__XFo_iGSqS0___iGSqS0___ : $@convention(thin) (@in Optional<AddrOnly>, @owned @callee_owned (@in Optional<AddrOnly>) -> @out AddrOnly) -> @out Optional<AddrOnly>
// CHECK:         alloc_stack $AddrOnly
// CHECK-NEXT:    apply %2(%3, %1)
// CHECK-NEXT:    init_enum_data_addr %0 : $*Optional<AddrOnly>
// CHECK-NEXT:    copy_addr [take] {{.*}} to [initialization] {{.*}} : $*AddrOnly
// CHECK-NEXT:    inject_enum_addr %0 : $*Optional<AddrOnly>
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    dealloc_stack {{.*}} : $*AddrOnly
// CHECK-NEXT:    return

// ==== Existentials

protocol Q {
  var n: Int8 { get }
}

protocol P : Q {}

extension Trivial : P {}
extension Loadable : P {}
extension AddrOnly : P {}

// CHECK-LABEL: sil hidden @_TF19function_conversion22convExistentialTrivialFTFPS_1Q_VS_7Trivial2t3FGSqPS0___S1__T_
func convExistentialTrivial(_ t2: @escaping (Q) -> Trivial, t3: @escaping (Q?) -> Trivial) {
// CHECK:         function_ref @_TTRXFo_iP19function_conversion1Q__dVS_7Trivial_XFo_dS1__iPS_1P__
// CHECK:         partial_apply
  let _: (Trivial) -> P = t2

// CHECK:         function_ref @_TTRXFo_iGSqP19function_conversion1Q___dVS_7Trivial_XFo_dGSqS1___iPS_1P__
// CHECK:         partial_apply
  let _: (Trivial?) -> P = t3

// CHECK:         function_ref @_TTRXFo_iP19function_conversion1Q__dVS_7Trivial_XFo_iPS_1P__iPS2___
// CHECK:         partial_apply
  let _: (P) -> P = t2
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iP19function_conversion1Q__dVS_7Trivial_XFo_dS1__iPS_1P__ : $@convention(thin) (Trivial, @owned @callee_owned (@in Q) -> Trivial) -> @out P
// CHECK:         alloc_stack $Q
// CHECK-NEXT:    init_existential_addr
// CHECK-NEXT:    store
// CHECK-NEXT:    apply
// CHECK-NEXT:    init_existential_addr
// CHECK-NEXT:    store
// CHECK:         return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iGSqP19function_conversion1Q___dVS_7Trivial_XFo_dGSqS1___iPS_1P__
// CHECK:         select_enum
// CHECK:         cond_br
// CHECK: bb1:
// CHECK:         unchecked_enum_data
// CHECK:         init_existential_addr
// CHECK:         init_enum_data_addr
// CHECK:         copy_addr
// CHECK:         inject_enum_addr
// CHECK: bb2:
// CHECK:         inject_enum_addr
// CHECK: bb3:
// CHECK:         apply
// CHECK:         init_existential_addr
// CHECK:         store
// CHECK:         return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iP19function_conversion1Q__dVS_7Trivial_XFo_iPS_1P__iPS2___ : $@convention(thin) (@in P, @owned @callee_owned (@in Q) -> Trivial) -> @out P
// CHECK:         alloc_stack $Q
// CHECK-NEXT:    open_existential_addr %1 : $*P
// CHECK-NEXT:    init_existential_addr %3 : $*Q
// CHECK-NEXT:    copy_addr [take] {{.*}} to [initialization] {{.*}}
// CHECK-NEXT:    apply
// CHECK-NEXT:    init_existential_addr
// CHECK-NEXT:    store
// CHECK:         deinit_existential_addr
// CHECK:         return

// ==== Existential metatypes

// CHECK-LABEL: sil hidden @_TF19function_conversion23convExistentialMetatypeFFGSqPMPS_1Q__MVS_7TrivialT_
func convExistentialMetatype(_ em: @escaping (Q.Type?) -> Trivial.Type) {
// CHECK:         function_ref @_TTRXFo_dGSqXPMTP19function_conversion1Q___dXMtVS_7Trivial_XFo_dXMtS1__dXPMTPS_1P__
// CHECK:         partial_apply
  let _: (Trivial.Type) -> P.Type = em

// CHECK:         function_ref @_TTRXFo_dGSqXPMTP19function_conversion1Q___dXMtVS_7Trivial_XFo_dGSqXMtS1___dXPMTPS_1P__
// CHECK:         partial_apply
  let _: (Trivial.Type?) -> P.Type = em

// CHECK:         function_ref @_TTRXFo_dGSqXPMTP19function_conversion1Q___dXMtVS_7Trivial_XFo_dXPMTPS_1P__dXPMTPS2___
// CHECK:         partial_apply
  let _: (P.Type) -> P.Type = em
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqXPMTP19function_conversion1Q___dXMtVS_7Trivial_XFo_dXMtS1__dXPMTPS_1P__ : $@convention(thin) (@thin Trivial.Type, @owned @callee_owned (Optional<@thick Q.Type>) -> @thin Trivial.Type) -> @thick P.Type
// CHECK:         metatype $@thick Trivial.Type
// CHECK-NEXT:    init_existential_metatype %2 : $@thick Trivial.Type, $@thick Q.Type
// CHECK-NEXT:    enum $Optional<@thick Q.Type>
// CHECK-NEXT:    apply
// CHECK-NEXT:    metatype $@thick Trivial.Type
// CHECK-NEXT:    init_existential_metatype {{.*}} : $@thick Trivial.Type, $@thick P.Type
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqXPMTP19function_conversion1Q___dXMtVS_7Trivial_XFo_dGSqXMtS1___dXPMTPS_1P__ : $@convention(thin) (Optional<@thin Trivial.Type>, @owned @callee_owned (Optional<@thick Q.Type>) -> @thin Trivial.Type) -> @thick P.Type
// CHECK:         select_enum %0 : $Optional<@thin Trivial.Type>
// CHECK-NEXT:    cond_br
// CHECK: bb1:
// CHECK-NEXT:    unchecked_enum_data %0 : $Optional<@thin Trivial.Type>
// CHECK-NEXT:    metatype $@thick Trivial.Type
// CHECK-NEXT:    init_existential_metatype {{.*}} : $@thick Trivial.Type, $@thick Q.Type
// CHECK-NEXT:    enum $Optional<@thick Q.Type>
// CHECK: bb2:
// CHECK-NEXT:    enum $Optional<@thick Q.Type>
// CHECK: bb3({{.*}}):
// CHECK-NEXT:    apply
// CHECK-NEXT:    metatype $@thick Trivial.Type
// CHECK-NEXT:    init_existential_metatype {{.*}} : $@thick Trivial.Type, $@thick P.Type
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqXPMTP19function_conversion1Q___dXMtVS_7Trivial_XFo_dXPMTPS_1P__dXPMTPS2___ : $@convention(thin) (@thick P.Type, @owned @callee_owned (Optional<@thick Q.Type>) -> @thin Trivial.Type) -> @thick P.Type
// CHECK:         open_existential_metatype %0 : $@thick P.Type to $@thick (@opened({{.*}}) P).Type
// CHECK-NEXT:    init_existential_metatype %2 : $@thick (@opened({{.*}}) P).Type, $@thick Q.Type
// CHECK-NEXT:    enum $Optional<@thick Q.Type>
// CHECK-NEXT:    apply
// CHECK-NEXT:    metatype $@thick Trivial.Type
// CHECK-NEXT:    init_existential_metatype {{.*}} : $@thick Trivial.Type, $@thick P.Type
// CHECK-NEXT:    return

// ==== Class metatype upcasts

class Parent {}
class Child : Parent {}

// Note: we add a Trivial => Trivial? conversion here to force a thunk
// to be generated

// CHECK-LABEL: sil hidden @_TF19function_conversion18convUpcastMetatypeFTFTMCS_6ParentGSqVS_7Trivial__MCS_5Child2c5FTGSqMS0__GSqS1___MS2__T_
func convUpcastMetatype(_ c4: @escaping (Parent.Type, Trivial?) -> Child.Type,
                        c5: @escaping (Parent.Type?, Trivial?) -> Child.Type) {
// CHECK:         function_ref @_TTRXFo_dXMTC19function_conversion6ParentdGSqVS_7Trivial__dXMTCS_5Child_XFo_dXMTS2_dS1__dXMTS0__
// CHECK:         partial_apply
  let _: (Child.Type, Trivial) -> Parent.Type = c4

// CHECK:         function_ref @_TTRXFo_dGSqXMTC19function_conversion6Parent_dGSqVS_7Trivial__dXMTCS_5Child_XFo_dXMTS2_dS1__dXMTS0__
// CHECK:         partial_apply
  let _: (Child.Type, Trivial) -> Parent.Type = c5

// CHECK:         function_ref @_TTRXFo_dGSqXMTC19function_conversion6Parent_dGSqVS_7Trivial__dXMTCS_5Child_XFo_dGSqXMTS2__dS1__dGSqXMTS0___
// CHECK:         partial_apply
  let _: (Child.Type?, Trivial) -> Parent.Type? = c5
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dXMTC19function_conversion6ParentdGSqVS_7Trivial__dXMTCS_5Child_XFo_dXMTS2_dS1__dXMTS0__ : $@convention(thin) (@thick Child.Type, Trivial, @owned @callee_owned (@thick Parent.Type, Optional<Trivial>) -> @thick Child.Type) -> @thick Parent.Type
// CHECK:         upcast %0 : $@thick Child.Type to $@thick Parent.Type
// CHECK:         apply
// CHECK:         upcast {{.*}} : $@thick Child.Type to $@thick Parent.Type
// CHECK:         return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqXMTC19function_conversion6Parent_dGSqVS_7Trivial__dXMTCS_5Child_XFo_dXMTS2_dS1__dXMTS0__ : $@convention(thin) (@thick Child.Type, Trivial, @owned @callee_owned (Optional<@thick Parent.Type>, Optional<Trivial>) -> @thick Child.Type) -> @thick Parent.Type
// CHECK:         upcast %0 : $@thick Child.Type to $@thick Parent.Type
// CHECK:         enum $Optional<@thick Parent.Type>
// CHECK:         apply
// CHECK:         upcast {{.*}} : $@thick Child.Type to $@thick Parent.Type
// CHECK:         return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqXMTC19function_conversion6Parent_dGSqVS_7Trivial__dXMTCS_5Child_XFo_dGSqXMTS2__dS1__dGSqXMTS0___ : $@convention(thin) (Optional<@thick Child.Type>, Trivial, @owned @callee_owned (Optional<@thick Parent.Type>, Optional<Trivial>) -> @thick Child.Type) -> Optional<@thick Parent.Type>
// CHECK:         unchecked_trivial_bit_cast %0 : $Optional<@thick Child.Type> to $Optional<@thick Parent.Type>
// CHECK:         apply
// CHECK:         upcast {{.*}} : $@thick Child.Type to $@thick Parent.Type
// CHECK:         enum $Optional<@thick Parent.Type>
// CHECK:         return

// ==== Function to existential -- make sure we maximally abstract it

// CHECK-LABEL: sil hidden @_TF19function_conversion19convFuncExistentialFFP_FSiSiT_ : $@convention(thin) (@owned @callee_owned (@in Any) -> @owned @callee_owned (Int) -> Int) -> ()
// CHECK: bb0([[ARG:%.*]] :
// CHECK:   [[ARG_COPY:%.*]] = copy_value [[ARG]]
// CHECK:   [[REABSTRACT_THUNK:%.*]] = function_ref @_TTRXFo_iP__oXFo_dSi_dSi__XFo_oXFo_dSi_dSi__iP__
// CHECK:   [[PA:%.*]] = partial_apply [[REABSTRACT_THUNK]]([[ARG_COPY]])
// CHECK:   destroy_value [[PA]]
// CHECK:   destroy_value [[ARG]]
// CHECK: } // end sil function '_TF19function_conversion19convFuncExistentialFFP_FSiSiT_'
func convFuncExistential(_ f1: @escaping (Any) -> (Int) -> Int) {
  let _: ((Int) -> Int) -> Any = f1
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iP__oXFo_dSi_dSi__XFo_oXFo_dSi_dSi__iP__ : $@convention(thin) (@owned @callee_owned (Int) -> Int, @owned @callee_owned (@in Any) -> @owned @callee_owned (Int) -> Int) -> @out Any
// CHECK:         alloc_stack $Any
// CHECK:         function_ref @_TTRXFo_dSi_dSi_XFo_iSi_iSi_
// CHECK-NEXT:    partial_apply
// CHECK-NEXT:    init_existential_addr %3 : $*Any, $(Int) -> Int
// CHECK-NEXT:    store
// CHECK-NEXT:    apply
// CHECK:         function_ref @_TTRXFo_dSi_dSi_XFo_iSi_iSi_
// CHECK-NEXT:    partial_apply
// CHECK-NEXT:    init_existential_addr %0 : $*Any, $(Int) -> Int
// CHECK-NEXT:    store {{.*}} to {{.*}} : $*@callee_owned (@in Int) -> @out Int
// CHECK:         return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dSi_dSi_XFo_iSi_iSi_ : $@convention(thin) (@in Int, @owned @callee_owned (Int) -> Int) -> @out Int
// CHECK:         load [trivial] %1 : $*Int
// CHECK-NEXT:    apply %2(%3)
// CHECK-NEXT:    store {{.*}} to [trivial] %0
// CHECK:         return

// ==== Class-bound archetype upcast

// CHECK-LABEL: sil hidden @_TF19function_conversion29convClassBoundArchetypeUpcast
func convClassBoundArchetypeUpcast<T : Parent>(_ f1: @escaping (Parent) -> (T, Trivial)) {
// CHECK:         function_ref @_TTRGRxC19function_conversion6ParentrXFo_oS0__oxdVS_7Trivial_XFo_ox_oS0_dGSqS1___
// CHECK:         partial_apply
  let _: (T) -> (Parent, Trivial?) = f1
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRGRxC19function_conversion6ParentrXFo_oS0__oxdVS_7Trivial_XFo_ox_oS0_dGSqS1___ : $@convention(thin) <T where T : Parent> (@owned T, @owned @callee_owned (@owned Parent) -> (@owned T, Trivial)) -> (@owned Parent, Optional<Trivial>)
// CHECK:         upcast %0 : $T to $Parent
// CHECK-NEXT:    apply
// CHECK-NEXT:    tuple_extract
// CHECK-NEXT:    tuple_extract
// CHECK-NEXT:    upcast {{.*}} : $T to $Parent
// CHECK-NEXT:    enum $Optional<Trivial>
// CHECK-NEXT:    tuple
// CHECK-NEXT:    return

// CHECK-LABEL: sil hidden @_TF19function_conversion37convClassBoundMetatypeArchetypeUpcast
func convClassBoundMetatypeArchetypeUpcast<T : Parent>(_ f1: @escaping (Parent.Type) -> (T.Type, Trivial)) {
// CHECK:         function_ref @_TTRGRxC19function_conversion6ParentrXFo_dXMTS0__dXMTxdVS_7Trivial_XFo_dXMTx_dXMTS0_dGSqS1___
// CHECK:         partial_apply
  let _: (T.Type) -> (Parent.Type, Trivial?) = f1
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRGRxC19function_conversion6ParentrXFo_dXMTS0__dXMTxdVS_7Trivial_XFo_dXMTx_dXMTS0_dGSqS1___ : $@convention(thin) <T where T : Parent> (@thick T.Type, @owned @callee_owned (@thick Parent.Type) -> (@thick T.Type, Trivial)) -> (@thick Parent.Type, Optional<Trivial>)
// CHECK:         upcast %0 : $@thick T.Type to $@thick Parent.Type
// CHECK-NEXT:    apply
// CHECK-NEXT:    tuple_extract
// CHECK-NEXT:    tuple_extract
// CHECK-NEXT:    upcast {{.*}} : $@thick T.Type to $@thick Parent.Type
// CHECK-NEXT:    enum $Optional<Trivial>
// CHECK-NEXT:    tuple
// CHECK-NEXT:    return

// ==== Make sure we destructure one-element tuples

// CHECK-LABEL: sil hidden @_TF19function_conversion15convTupleScalarFTFPS_1Q_T_2f2FPS0__T_2f3FGSqTSiSi__T__T_
// CHECK:         function_ref @_TTRXFo_iP19function_conversion1Q___XFo_iPS_1P___
// CHECK:         function_ref @_TTRXFo_iP19function_conversion1Q___XFo_iPS_1P___
// CHECK:         function_ref @_TTRXFo_dGSqTSiSi____XFo_dSidSi__

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iP19function_conversion1Q___XFo_iPS_1P___ : $@convention(thin) (@in P, @owned @callee_owned (@in Q) -> ()) -> ()

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_dGSqTSiSi____XFo_dSidSi__ : $@convention(thin) (Int, Int, @owned @callee_owned (Optional<(Int, Int)>) -> ()) -> ()

func convTupleScalar(_ f1: @escaping (Q) -> (),
                     f2: @escaping (_ parent: Q) -> (),
                     f3: @escaping (_ tuple: (Int, Int)?) -> ()) {
  let _: (P) -> () = f1
  let _: (P) -> () = f2
  let _: (Int, Int) -> () = f3
}

func convTupleScalarOpaque<T>(_ f: @escaping (T...) -> ()) -> ((_ args: T...) -> ())? {
  return f
}

// ==== Make sure we support AnyHashable erasure

// CHECK-LABEL: sil hidden @_TF19function_conversion15convAnyHashableuRxs8HashablerFT1tx_T_
// CHECK:         function_ref @_TFF19function_conversion15convAnyHashableuRxs8HashablerFT1tx_T_U_FTVs11AnyHashableS1__Sb
// CHECK:         function_ref @_TTRGRxs8HashablerXFo_iVs11AnyHashableiS0__dSb_XFo_ixix_dSb_

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRGRxs8HashablerXFo_iVs11AnyHashableiS0__dSb_XFo_ixix_dSb_ : $@convention(thin) <T where T : Hashable> (@in T, @in T, @owned @callee_owned (@in AnyHashable, @in AnyHashable) -> Bool) -> Bool
// CHECK:         alloc_stack $AnyHashable
// CHECK:         function_ref @_swift_convertToAnyHashable
// CHECK:         apply {{.*}}<T>
// CHECK:         alloc_stack $AnyHashable
// CHECK:         function_ref @_swift_convertToAnyHashable
// CHECK:         apply {{.*}}<T>
// CHECK:         return

func convAnyHashable<T : Hashable>(t: T) {
  let fn: (T, T) -> Bool = {
    (x: AnyHashable, y: AnyHashable) in x == y
  }
}

// ==== Convert exploded tuples to Any or Optional<Any>

// CHECK-LABEL: sil hidden @_TF19function_conversion12convTupleAnyFTFT_T_FT_TSiSi_FP_T_FGSqP__T__T_
// CHECK:         function_ref @_TTRXFo___XFo__iP__
// CHECK:         partial_apply
// CHECK:         function_ref @_TTRXFo___XFo__iGSqP___
// CHECK:         partial_apply
// CHECK:         function_ref @_TTRXFo__dSidSi_XFo__iP__
// CHECK:         partial_apply
// CHECK:         function_ref @_TTRXFo__dSidSi_XFo__iGSqP___
// CHECK:         partial_apply
// CHECK:         function_ref @_TTRXFo_iP___XFo_dSidSi__
// CHECK:         partial_apply
// CHECK:         function_ref @_TTRXFo_iGSqP____XFo_dSidSi__
// CHECK:         partial_apply

func convTupleAny(_ f1: @escaping () -> (),
                  _ f2: @escaping () -> (Int, Int),
                  _ f3: @escaping (Any) -> (),
                  _ f4: @escaping (Any?) -> ()) {
  let _: () -> Any = f1
  let _: () -> Any? = f1

  let _: () -> Any = f2
  let _: () -> Any? = f2

  let _: ((Int, Int)) -> () = f3

  let _: ((Int, Int)) -> () = f4
}

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo___XFo__iP__ : $@convention(thin) (@owned @callee_owned () -> ()) -> @out Any
// CHECK:         init_existential_addr %0 : $*Any, $()
// CHECK-NEXT:    apply %1()
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo___XFo__iGSqP___ : $@convention(thin) (@owned @callee_owned () -> ()) -> @out Optional<Any>
// CHECK:         [[ENUM_PAYLOAD:%.*]] = init_enum_data_addr %0 : $*Optional<Any>, #Optional.some!enumelt.1
// CHECK-NEXT:    init_existential_addr [[ENUM_PAYLOAD]] : $*Any, $()
// CHECK-NEXT:    apply %1()
// CHECK-NEXT:    inject_enum_addr %0 : $*Optional<Any>, #Optional.some!enumelt.1
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo__dSidSi_XFo__iP__ : $@convention(thin) (@owned @callee_owned () -> (Int, Int)) -> @out Any
// CHECK:         [[ANY_PAYLOAD:%.*]] = init_existential_addr %0
// CHECK-NEXT:    [[LEFT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    [[RIGHT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    [[RESULT:%.*]] = apply %1()
// CHECK-NEXT:    [[LEFT:%.*]] = tuple_extract [[RESULT]]
// CHECK-NEXT:    [[RIGHT:%.*]] = tuple_extract [[RESULT]]
// CHECK-NEXT:    store [[LEFT:%.*]] to [trivial] [[LEFT_ADDR]]
// CHECK-NEXT:    store [[RIGHT:%.*]] to [trivial] [[RIGHT_ADDR]]
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo__dSidSi_XFo__iGSqP___ : $@convention(thin) (@owned @callee_owned () -> (Int, Int)) -> @out Optional<Any> {
// CHECK:         [[OPTIONAL_PAYLOAD:%.*]] = init_enum_data_addr %0
// CHECK-NEXT:    [[ANY_PAYLOAD:%.*]] = init_existential_addr [[OPTIONAL_PAYLOAD]]
// CHECK-NEXT:    [[LEFT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    [[RIGHT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    [[RESULT:%.*]] = apply %1()
// CHECK-NEXT:    [[LEFT:%.*]] = tuple_extract [[RESULT]]
// CHECK-NEXT:    [[RIGHT:%.*]] = tuple_extract [[RESULT]]
// CHECK-NEXT:    store [[LEFT:%.*]] to [trivial] [[LEFT_ADDR]]
// CHECK-NEXT:    store [[RIGHT:%.*]] to [trivial] [[RIGHT_ADDR]]
// CHECK-NEXT:    inject_enum_addr %0
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iP___XFo_dSidSi__ : $@convention(thin) (Int, Int, @owned @callee_owned (@in Any) -> ()) -> ()
// CHECK:         [[ANY_VALUE:%.*]] = alloc_stack $Any
// CHECK-NEXT:    [[ANY_PAYLOAD:%.*]] = init_existential_addr [[ANY_VALUE]]
// CHECK-NEXT:    [[LEFT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    store %0 to [trivial] [[LEFT_ADDR]]
// CHECK-NEXT:    [[RIGHT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    store %1 to [trivial] [[RIGHT_ADDR]]
// CHECK-NEXT:    apply %2([[ANY_VALUE]])
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    dealloc_stack [[ANY_VALUE]]
// CHECK-NEXT:    return

// CHECK-LABEL: sil shared [transparent] [reabstraction_thunk] @_TTRXFo_iGSqP____XFo_dSidSi__ : $@convention(thin) (Int, Int, @owned @callee_owned (@in Optional<Any>) -> ()) -> ()
// CHECK:         [[ANY_VALUE:%.*]] = alloc_stack $Any
// CHECK-NEXT:    [[ANY_PAYLOAD:%.*]] = init_existential_addr [[ANY_VALUE]]
// CHECK-NEXT:    [[LEFT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    store %0 to [trivial] [[LEFT_ADDR]]
// CHECK-NEXT:    [[RIGHT_ADDR:%.*]] = tuple_element_addr [[ANY_PAYLOAD]]
// CHECK-NEXT:    store %1 to [trivial] [[RIGHT_ADDR]]
// CHECK-NEXT:    [[OPTIONAL_VALUE:%.*]] = alloc_stack $Optional<Any>
// CHECK-NEXT:    [[OPTIONAL_PAYLOAD:%.*]] = init_enum_data_addr [[OPTIONAL_VALUE]]
// CHECK-NEXT:    copy_addr [take] [[ANY_VALUE]] to [initialization] [[OPTIONAL_PAYLOAD]]
// CHECK-NEXT:    inject_enum_addr [[OPTIONAL_VALUE]]
// CHECK-NEXT:    apply %2([[OPTIONAL_VALUE]])
// CHECK-NEXT:    tuple ()
// CHECK-NEXT:    dealloc_stack [[OPTIONAL_VALUE]]
// CHECK-NEXT:    dealloc_stack [[ANY_VALUE]]
// CHECK-NEXT:    return
