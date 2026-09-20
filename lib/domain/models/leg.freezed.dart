// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'leg.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Leg {

 String get id; String get cycleId; int get sequence; OptionType get optionType;@DecimalJsonConverter() Decimal get strike; DateTime get expiration; int get contracts; DateTime get openedAt;@DecimalJsonConverter() Decimal get openCreditPerShare; DateTime? get closedAt;@NullableDecimalJsonConverter() Decimal? get closeDebitPerShare; CloseReason? get closeReason; String? get rolledFromLegId; String get ruleProfileVersionId; double? get ivAtOpen; double? get ivRankAtOpen; double? get deltaAtOpen;@NullableDecimalJsonConverter() Decimal? get underlyingPriceAtOpen;/// Total fee for opening this leg's transaction, in dollars (integer
/// cents on disk) — never per-share, never per-contract (Phase 15).
/// `null` means "not recorded," never zero (§4.3) — a pre-v3 leg
/// migrates to `null`, and callers must not coerce a missing fee to
/// `Decimal.zero` anywhere above the persistence boundary.
@NullableDecimalJsonConverter() Decimal? get openFee;/// Same shape as [openFee], for the transaction that closed this leg.
/// Always `null` while [closedAt] is still `null` (Feature Invariant
/// 28: an open leg's missing closing cost is expected, not a gap).
@NullableDecimalJsonConverter() Decimal? get closeFee;/// Whether this leg's owner is willing to be assigned rather than roll
/// (Gate 2, `docs/brief-ledger.md` §3.3). Set once at leg creation;
/// existing pre-v3 rows migrate to `true`. A roll's new leg inherits or
/// re-asks this value at the caller's discretion (`lib/state/`) — the
/// repository itself never derives it.
 bool get acceptsAssignment;
/// Create a copy of Leg
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LegCopyWith<Leg> get copyWith => _$LegCopyWithImpl<Leg>(this as Leg, _$identity);

  /// Serializes this Leg to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Leg&&(identical(other.id, id) || other.id == id)&&(identical(other.cycleId, cycleId) || other.cycleId == cycleId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.optionType, optionType) || other.optionType == optionType)&&(identical(other.strike, strike) || other.strike == strike)&&(identical(other.expiration, expiration) || other.expiration == expiration)&&(identical(other.contracts, contracts) || other.contracts == contracts)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.openCreditPerShare, openCreditPerShare) || other.openCreditPerShare == openCreditPerShare)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.closeDebitPerShare, closeDebitPerShare) || other.closeDebitPerShare == closeDebitPerShare)&&(identical(other.closeReason, closeReason) || other.closeReason == closeReason)&&(identical(other.rolledFromLegId, rolledFromLegId) || other.rolledFromLegId == rolledFromLegId)&&(identical(other.ruleProfileVersionId, ruleProfileVersionId) || other.ruleProfileVersionId == ruleProfileVersionId)&&(identical(other.ivAtOpen, ivAtOpen) || other.ivAtOpen == ivAtOpen)&&(identical(other.ivRankAtOpen, ivRankAtOpen) || other.ivRankAtOpen == ivRankAtOpen)&&(identical(other.deltaAtOpen, deltaAtOpen) || other.deltaAtOpen == deltaAtOpen)&&(identical(other.underlyingPriceAtOpen, underlyingPriceAtOpen) || other.underlyingPriceAtOpen == underlyingPriceAtOpen)&&(identical(other.openFee, openFee) || other.openFee == openFee)&&(identical(other.closeFee, closeFee) || other.closeFee == closeFee)&&(identical(other.acceptsAssignment, acceptsAssignment) || other.acceptsAssignment == acceptsAssignment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,cycleId,sequence,optionType,strike,expiration,contracts,openedAt,openCreditPerShare,closedAt,closeDebitPerShare,closeReason,rolledFromLegId,ruleProfileVersionId,ivAtOpen,ivRankAtOpen,deltaAtOpen,underlyingPriceAtOpen,openFee,closeFee,acceptsAssignment]);

@override
String toString() {
  return 'Leg(id: $id, cycleId: $cycleId, sequence: $sequence, optionType: $optionType, strike: $strike, expiration: $expiration, contracts: $contracts, openedAt: $openedAt, openCreditPerShare: $openCreditPerShare, closedAt: $closedAt, closeDebitPerShare: $closeDebitPerShare, closeReason: $closeReason, rolledFromLegId: $rolledFromLegId, ruleProfileVersionId: $ruleProfileVersionId, ivAtOpen: $ivAtOpen, ivRankAtOpen: $ivRankAtOpen, deltaAtOpen: $deltaAtOpen, underlyingPriceAtOpen: $underlyingPriceAtOpen, openFee: $openFee, closeFee: $closeFee, acceptsAssignment: $acceptsAssignment)';
}


}

/// @nodoc
abstract mixin class $LegCopyWith<$Res>  {
  factory $LegCopyWith(Leg value, $Res Function(Leg) _then) = _$LegCopyWithImpl;
@useResult
$Res call({
 String id, String cycleId, int sequence, OptionType optionType,@DecimalJsonConverter() Decimal strike, DateTime expiration, int contracts, DateTime openedAt,@DecimalJsonConverter() Decimal openCreditPerShare, DateTime? closedAt,@NullableDecimalJsonConverter() Decimal? closeDebitPerShare, CloseReason? closeReason, String? rolledFromLegId, String ruleProfileVersionId, double? ivAtOpen, double? ivRankAtOpen, double? deltaAtOpen,@NullableDecimalJsonConverter() Decimal? underlyingPriceAtOpen,@NullableDecimalJsonConverter() Decimal? openFee,@NullableDecimalJsonConverter() Decimal? closeFee, bool acceptsAssignment
});




}
/// @nodoc
class _$LegCopyWithImpl<$Res>
    implements $LegCopyWith<$Res> {
  _$LegCopyWithImpl(this._self, this._then);

  final Leg _self;
  final $Res Function(Leg) _then;

/// Create a copy of Leg
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? cycleId = null,Object? sequence = null,Object? optionType = null,Object? strike = null,Object? expiration = null,Object? contracts = null,Object? openedAt = null,Object? openCreditPerShare = null,Object? closedAt = freezed,Object? closeDebitPerShare = freezed,Object? closeReason = freezed,Object? rolledFromLegId = freezed,Object? ruleProfileVersionId = null,Object? ivAtOpen = freezed,Object? ivRankAtOpen = freezed,Object? deltaAtOpen = freezed,Object? underlyingPriceAtOpen = freezed,Object? openFee = freezed,Object? closeFee = freezed,Object? acceptsAssignment = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,cycleId: null == cycleId ? _self.cycleId : cycleId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,optionType: null == optionType ? _self.optionType : optionType // ignore: cast_nullable_to_non_nullable
as OptionType,strike: null == strike ? _self.strike : strike // ignore: cast_nullable_to_non_nullable
as Decimal,expiration: null == expiration ? _self.expiration : expiration // ignore: cast_nullable_to_non_nullable
as DateTime,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,openedAt: null == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as DateTime,openCreditPerShare: null == openCreditPerShare ? _self.openCreditPerShare : openCreditPerShare // ignore: cast_nullable_to_non_nullable
as Decimal,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closeDebitPerShare: freezed == closeDebitPerShare ? _self.closeDebitPerShare : closeDebitPerShare // ignore: cast_nullable_to_non_nullable
as Decimal?,closeReason: freezed == closeReason ? _self.closeReason : closeReason // ignore: cast_nullable_to_non_nullable
as CloseReason?,rolledFromLegId: freezed == rolledFromLegId ? _self.rolledFromLegId : rolledFromLegId // ignore: cast_nullable_to_non_nullable
as String?,ruleProfileVersionId: null == ruleProfileVersionId ? _self.ruleProfileVersionId : ruleProfileVersionId // ignore: cast_nullable_to_non_nullable
as String,ivAtOpen: freezed == ivAtOpen ? _self.ivAtOpen : ivAtOpen // ignore: cast_nullable_to_non_nullable
as double?,ivRankAtOpen: freezed == ivRankAtOpen ? _self.ivRankAtOpen : ivRankAtOpen // ignore: cast_nullable_to_non_nullable
as double?,deltaAtOpen: freezed == deltaAtOpen ? _self.deltaAtOpen : deltaAtOpen // ignore: cast_nullable_to_non_nullable
as double?,underlyingPriceAtOpen: freezed == underlyingPriceAtOpen ? _self.underlyingPriceAtOpen : underlyingPriceAtOpen // ignore: cast_nullable_to_non_nullable
as Decimal?,openFee: freezed == openFee ? _self.openFee : openFee // ignore: cast_nullable_to_non_nullable
as Decimal?,closeFee: freezed == closeFee ? _self.closeFee : closeFee // ignore: cast_nullable_to_non_nullable
as Decimal?,acceptsAssignment: null == acceptsAssignment ? _self.acceptsAssignment : acceptsAssignment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Leg].
extension LegPatterns on Leg {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Leg value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Leg() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Leg value)  $default,){
final _that = this;
switch (_that) {
case _Leg():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Leg value)?  $default,){
final _that = this;
switch (_that) {
case _Leg() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String cycleId,  int sequence,  OptionType optionType, @DecimalJsonConverter()  Decimal strike,  DateTime expiration,  int contracts,  DateTime openedAt, @DecimalJsonConverter()  Decimal openCreditPerShare,  DateTime? closedAt, @NullableDecimalJsonConverter()  Decimal? closeDebitPerShare,  CloseReason? closeReason,  String? rolledFromLegId,  String ruleProfileVersionId,  double? ivAtOpen,  double? ivRankAtOpen,  double? deltaAtOpen, @NullableDecimalJsonConverter()  Decimal? underlyingPriceAtOpen, @NullableDecimalJsonConverter()  Decimal? openFee, @NullableDecimalJsonConverter()  Decimal? closeFee,  bool acceptsAssignment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Leg() when $default != null:
return $default(_that.id,_that.cycleId,_that.sequence,_that.optionType,_that.strike,_that.expiration,_that.contracts,_that.openedAt,_that.openCreditPerShare,_that.closedAt,_that.closeDebitPerShare,_that.closeReason,_that.rolledFromLegId,_that.ruleProfileVersionId,_that.ivAtOpen,_that.ivRankAtOpen,_that.deltaAtOpen,_that.underlyingPriceAtOpen,_that.openFee,_that.closeFee,_that.acceptsAssignment);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String cycleId,  int sequence,  OptionType optionType, @DecimalJsonConverter()  Decimal strike,  DateTime expiration,  int contracts,  DateTime openedAt, @DecimalJsonConverter()  Decimal openCreditPerShare,  DateTime? closedAt, @NullableDecimalJsonConverter()  Decimal? closeDebitPerShare,  CloseReason? closeReason,  String? rolledFromLegId,  String ruleProfileVersionId,  double? ivAtOpen,  double? ivRankAtOpen,  double? deltaAtOpen, @NullableDecimalJsonConverter()  Decimal? underlyingPriceAtOpen, @NullableDecimalJsonConverter()  Decimal? openFee, @NullableDecimalJsonConverter()  Decimal? closeFee,  bool acceptsAssignment)  $default,) {final _that = this;
switch (_that) {
case _Leg():
return $default(_that.id,_that.cycleId,_that.sequence,_that.optionType,_that.strike,_that.expiration,_that.contracts,_that.openedAt,_that.openCreditPerShare,_that.closedAt,_that.closeDebitPerShare,_that.closeReason,_that.rolledFromLegId,_that.ruleProfileVersionId,_that.ivAtOpen,_that.ivRankAtOpen,_that.deltaAtOpen,_that.underlyingPriceAtOpen,_that.openFee,_that.closeFee,_that.acceptsAssignment);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String cycleId,  int sequence,  OptionType optionType, @DecimalJsonConverter()  Decimal strike,  DateTime expiration,  int contracts,  DateTime openedAt, @DecimalJsonConverter()  Decimal openCreditPerShare,  DateTime? closedAt, @NullableDecimalJsonConverter()  Decimal? closeDebitPerShare,  CloseReason? closeReason,  String? rolledFromLegId,  String ruleProfileVersionId,  double? ivAtOpen,  double? ivRankAtOpen,  double? deltaAtOpen, @NullableDecimalJsonConverter()  Decimal? underlyingPriceAtOpen, @NullableDecimalJsonConverter()  Decimal? openFee, @NullableDecimalJsonConverter()  Decimal? closeFee,  bool acceptsAssignment)?  $default,) {final _that = this;
switch (_that) {
case _Leg() when $default != null:
return $default(_that.id,_that.cycleId,_that.sequence,_that.optionType,_that.strike,_that.expiration,_that.contracts,_that.openedAt,_that.openCreditPerShare,_that.closedAt,_that.closeDebitPerShare,_that.closeReason,_that.rolledFromLegId,_that.ruleProfileVersionId,_that.ivAtOpen,_that.ivRankAtOpen,_that.deltaAtOpen,_that.underlyingPriceAtOpen,_that.openFee,_that.closeFee,_that.acceptsAssignment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Leg implements Leg {
  const _Leg({required this.id, required this.cycleId, required this.sequence, required this.optionType, @DecimalJsonConverter() required this.strike, required this.expiration, required this.contracts, required this.openedAt, @DecimalJsonConverter() required this.openCreditPerShare, this.closedAt, @NullableDecimalJsonConverter() this.closeDebitPerShare, this.closeReason, this.rolledFromLegId, required this.ruleProfileVersionId, this.ivAtOpen, this.ivRankAtOpen, this.deltaAtOpen, @NullableDecimalJsonConverter() this.underlyingPriceAtOpen, @NullableDecimalJsonConverter() this.openFee, @NullableDecimalJsonConverter() this.closeFee, this.acceptsAssignment = true});
  factory _Leg.fromJson(Map<String, dynamic> json) => _$LegFromJson(json);

@override final  String id;
@override final  String cycleId;
@override final  int sequence;
@override final  OptionType optionType;
@override@DecimalJsonConverter() final  Decimal strike;
@override final  DateTime expiration;
@override final  int contracts;
@override final  DateTime openedAt;
@override@DecimalJsonConverter() final  Decimal openCreditPerShare;
@override final  DateTime? closedAt;
@override@NullableDecimalJsonConverter() final  Decimal? closeDebitPerShare;
@override final  CloseReason? closeReason;
@override final  String? rolledFromLegId;
@override final  String ruleProfileVersionId;
@override final  double? ivAtOpen;
@override final  double? ivRankAtOpen;
@override final  double? deltaAtOpen;
@override@NullableDecimalJsonConverter() final  Decimal? underlyingPriceAtOpen;
/// Total fee for opening this leg's transaction, in dollars (integer
/// cents on disk) — never per-share, never per-contract (Phase 15).
/// `null` means "not recorded," never zero (§4.3) — a pre-v3 leg
/// migrates to `null`, and callers must not coerce a missing fee to
/// `Decimal.zero` anywhere above the persistence boundary.
@override@NullableDecimalJsonConverter() final  Decimal? openFee;
/// Same shape as [openFee], for the transaction that closed this leg.
/// Always `null` while [closedAt] is still `null` (Feature Invariant
/// 28: an open leg's missing closing cost is expected, not a gap).
@override@NullableDecimalJsonConverter() final  Decimal? closeFee;
/// Whether this leg's owner is willing to be assigned rather than roll
/// (Gate 2, `docs/brief-ledger.md` §3.3). Set once at leg creation;
/// existing pre-v3 rows migrate to `true`. A roll's new leg inherits or
/// re-asks this value at the caller's discretion (`lib/state/`) — the
/// repository itself never derives it.
@override@JsonKey() final  bool acceptsAssignment;

/// Create a copy of Leg
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LegCopyWith<_Leg> get copyWith => __$LegCopyWithImpl<_Leg>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LegToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Leg&&(identical(other.id, id) || other.id == id)&&(identical(other.cycleId, cycleId) || other.cycleId == cycleId)&&(identical(other.sequence, sequence) || other.sequence == sequence)&&(identical(other.optionType, optionType) || other.optionType == optionType)&&(identical(other.strike, strike) || other.strike == strike)&&(identical(other.expiration, expiration) || other.expiration == expiration)&&(identical(other.contracts, contracts) || other.contracts == contracts)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.openCreditPerShare, openCreditPerShare) || other.openCreditPerShare == openCreditPerShare)&&(identical(other.closedAt, closedAt) || other.closedAt == closedAt)&&(identical(other.closeDebitPerShare, closeDebitPerShare) || other.closeDebitPerShare == closeDebitPerShare)&&(identical(other.closeReason, closeReason) || other.closeReason == closeReason)&&(identical(other.rolledFromLegId, rolledFromLegId) || other.rolledFromLegId == rolledFromLegId)&&(identical(other.ruleProfileVersionId, ruleProfileVersionId) || other.ruleProfileVersionId == ruleProfileVersionId)&&(identical(other.ivAtOpen, ivAtOpen) || other.ivAtOpen == ivAtOpen)&&(identical(other.ivRankAtOpen, ivRankAtOpen) || other.ivRankAtOpen == ivRankAtOpen)&&(identical(other.deltaAtOpen, deltaAtOpen) || other.deltaAtOpen == deltaAtOpen)&&(identical(other.underlyingPriceAtOpen, underlyingPriceAtOpen) || other.underlyingPriceAtOpen == underlyingPriceAtOpen)&&(identical(other.openFee, openFee) || other.openFee == openFee)&&(identical(other.closeFee, closeFee) || other.closeFee == closeFee)&&(identical(other.acceptsAssignment, acceptsAssignment) || other.acceptsAssignment == acceptsAssignment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,cycleId,sequence,optionType,strike,expiration,contracts,openedAt,openCreditPerShare,closedAt,closeDebitPerShare,closeReason,rolledFromLegId,ruleProfileVersionId,ivAtOpen,ivRankAtOpen,deltaAtOpen,underlyingPriceAtOpen,openFee,closeFee,acceptsAssignment]);

@override
String toString() {
  return 'Leg(id: $id, cycleId: $cycleId, sequence: $sequence, optionType: $optionType, strike: $strike, expiration: $expiration, contracts: $contracts, openedAt: $openedAt, openCreditPerShare: $openCreditPerShare, closedAt: $closedAt, closeDebitPerShare: $closeDebitPerShare, closeReason: $closeReason, rolledFromLegId: $rolledFromLegId, ruleProfileVersionId: $ruleProfileVersionId, ivAtOpen: $ivAtOpen, ivRankAtOpen: $ivRankAtOpen, deltaAtOpen: $deltaAtOpen, underlyingPriceAtOpen: $underlyingPriceAtOpen, openFee: $openFee, closeFee: $closeFee, acceptsAssignment: $acceptsAssignment)';
}


}

/// @nodoc
abstract mixin class _$LegCopyWith<$Res> implements $LegCopyWith<$Res> {
  factory _$LegCopyWith(_Leg value, $Res Function(_Leg) _then) = __$LegCopyWithImpl;
@override @useResult
$Res call({
 String id, String cycleId, int sequence, OptionType optionType,@DecimalJsonConverter() Decimal strike, DateTime expiration, int contracts, DateTime openedAt,@DecimalJsonConverter() Decimal openCreditPerShare, DateTime? closedAt,@NullableDecimalJsonConverter() Decimal? closeDebitPerShare, CloseReason? closeReason, String? rolledFromLegId, String ruleProfileVersionId, double? ivAtOpen, double? ivRankAtOpen, double? deltaAtOpen,@NullableDecimalJsonConverter() Decimal? underlyingPriceAtOpen,@NullableDecimalJsonConverter() Decimal? openFee,@NullableDecimalJsonConverter() Decimal? closeFee, bool acceptsAssignment
});




}
/// @nodoc
class __$LegCopyWithImpl<$Res>
    implements _$LegCopyWith<$Res> {
  __$LegCopyWithImpl(this._self, this._then);

  final _Leg _self;
  final $Res Function(_Leg) _then;

/// Create a copy of Leg
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? cycleId = null,Object? sequence = null,Object? optionType = null,Object? strike = null,Object? expiration = null,Object? contracts = null,Object? openedAt = null,Object? openCreditPerShare = null,Object? closedAt = freezed,Object? closeDebitPerShare = freezed,Object? closeReason = freezed,Object? rolledFromLegId = freezed,Object? ruleProfileVersionId = null,Object? ivAtOpen = freezed,Object? ivRankAtOpen = freezed,Object? deltaAtOpen = freezed,Object? underlyingPriceAtOpen = freezed,Object? openFee = freezed,Object? closeFee = freezed,Object? acceptsAssignment = null,}) {
  return _then(_Leg(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,cycleId: null == cycleId ? _self.cycleId : cycleId // ignore: cast_nullable_to_non_nullable
as String,sequence: null == sequence ? _self.sequence : sequence // ignore: cast_nullable_to_non_nullable
as int,optionType: null == optionType ? _self.optionType : optionType // ignore: cast_nullable_to_non_nullable
as OptionType,strike: null == strike ? _self.strike : strike // ignore: cast_nullable_to_non_nullable
as Decimal,expiration: null == expiration ? _self.expiration : expiration // ignore: cast_nullable_to_non_nullable
as DateTime,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,openedAt: null == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as DateTime,openCreditPerShare: null == openCreditPerShare ? _self.openCreditPerShare : openCreditPerShare // ignore: cast_nullable_to_non_nullable
as Decimal,closedAt: freezed == closedAt ? _self.closedAt : closedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,closeDebitPerShare: freezed == closeDebitPerShare ? _self.closeDebitPerShare : closeDebitPerShare // ignore: cast_nullable_to_non_nullable
as Decimal?,closeReason: freezed == closeReason ? _self.closeReason : closeReason // ignore: cast_nullable_to_non_nullable
as CloseReason?,rolledFromLegId: freezed == rolledFromLegId ? _self.rolledFromLegId : rolledFromLegId // ignore: cast_nullable_to_non_nullable
as String?,ruleProfileVersionId: null == ruleProfileVersionId ? _self.ruleProfileVersionId : ruleProfileVersionId // ignore: cast_nullable_to_non_nullable
as String,ivAtOpen: freezed == ivAtOpen ? _self.ivAtOpen : ivAtOpen // ignore: cast_nullable_to_non_nullable
as double?,ivRankAtOpen: freezed == ivRankAtOpen ? _self.ivRankAtOpen : ivRankAtOpen // ignore: cast_nullable_to_non_nullable
as double?,deltaAtOpen: freezed == deltaAtOpen ? _self.deltaAtOpen : deltaAtOpen // ignore: cast_nullable_to_non_nullable
as double?,underlyingPriceAtOpen: freezed == underlyingPriceAtOpen ? _self.underlyingPriceAtOpen : underlyingPriceAtOpen // ignore: cast_nullable_to_non_nullable
as Decimal?,openFee: freezed == openFee ? _self.openFee : openFee // ignore: cast_nullable_to_non_nullable
as Decimal?,closeFee: freezed == closeFee ? _self.closeFee : closeFee // ignore: cast_nullable_to_non_nullable
as Decimal?,acceptsAssignment: null == acceptsAssignment ? _self.acceptsAssignment : acceptsAssignment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
