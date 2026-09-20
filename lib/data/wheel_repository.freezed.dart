// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wheel_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NewLegInput {

 OptionType get optionType; Decimal get strike; DateTime get expiration; int get contracts; DateTime get openedAt; Decimal get openCreditPerShare;/// The `rule_profile_version` id this leg pins
/// (`<profileId>-v<n>`, see [Leg.ruleProfileVersionId]) — always a
/// version id, never a bare profile id, so the leg's rules are truthful
/// to the moment it opened even after later edits.
 String get ruleProfileVersionId; double? get ivAtOpen; double? get ivRankAtOpen; double? get deltaAtOpen; Decimal? get underlyingPriceAtOpen;/// Total fee for opening this leg, in dollars — `null` means "not
/// recorded," never zero (Phase 15). Carried straight onto the created
/// [Leg].
 Decimal? get openFee;/// Whether this leg's owner accepts assignment rather than rolling
/// (Phase 15/16 Gate 2). Defaults to `true` when the caller doesn't
/// pass one (S-094); an explicit value (e.g. `false`, inherited across
/// a roll per S-095/S-102) is never overwritten by the repository.
 bool get acceptsAssignment;
/// Create a copy of NewLegInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewLegInputCopyWith<NewLegInput> get copyWith => _$NewLegInputCopyWithImpl<NewLegInput>(this as NewLegInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewLegInput&&(identical(other.optionType, optionType) || other.optionType == optionType)&&(identical(other.strike, strike) || other.strike == strike)&&(identical(other.expiration, expiration) || other.expiration == expiration)&&(identical(other.contracts, contracts) || other.contracts == contracts)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.openCreditPerShare, openCreditPerShare) || other.openCreditPerShare == openCreditPerShare)&&(identical(other.ruleProfileVersionId, ruleProfileVersionId) || other.ruleProfileVersionId == ruleProfileVersionId)&&(identical(other.ivAtOpen, ivAtOpen) || other.ivAtOpen == ivAtOpen)&&(identical(other.ivRankAtOpen, ivRankAtOpen) || other.ivRankAtOpen == ivRankAtOpen)&&(identical(other.deltaAtOpen, deltaAtOpen) || other.deltaAtOpen == deltaAtOpen)&&(identical(other.underlyingPriceAtOpen, underlyingPriceAtOpen) || other.underlyingPriceAtOpen == underlyingPriceAtOpen)&&(identical(other.openFee, openFee) || other.openFee == openFee)&&(identical(other.acceptsAssignment, acceptsAssignment) || other.acceptsAssignment == acceptsAssignment));
}


@override
int get hashCode => Object.hash(runtimeType,optionType,strike,expiration,contracts,openedAt,openCreditPerShare,ruleProfileVersionId,ivAtOpen,ivRankAtOpen,deltaAtOpen,underlyingPriceAtOpen,openFee,acceptsAssignment);

@override
String toString() {
  return 'NewLegInput(optionType: $optionType, strike: $strike, expiration: $expiration, contracts: $contracts, openedAt: $openedAt, openCreditPerShare: $openCreditPerShare, ruleProfileVersionId: $ruleProfileVersionId, ivAtOpen: $ivAtOpen, ivRankAtOpen: $ivRankAtOpen, deltaAtOpen: $deltaAtOpen, underlyingPriceAtOpen: $underlyingPriceAtOpen, openFee: $openFee, acceptsAssignment: $acceptsAssignment)';
}


}

/// @nodoc
abstract mixin class $NewLegInputCopyWith<$Res>  {
  factory $NewLegInputCopyWith(NewLegInput value, $Res Function(NewLegInput) _then) = _$NewLegInputCopyWithImpl;
@useResult
$Res call({
 OptionType optionType, Decimal strike, DateTime expiration, int contracts, DateTime openedAt, Decimal openCreditPerShare, String ruleProfileVersionId, double? ivAtOpen, double? ivRankAtOpen, double? deltaAtOpen, Decimal? underlyingPriceAtOpen, Decimal? openFee, bool acceptsAssignment
});




}
/// @nodoc
class _$NewLegInputCopyWithImpl<$Res>
    implements $NewLegInputCopyWith<$Res> {
  _$NewLegInputCopyWithImpl(this._self, this._then);

  final NewLegInput _self;
  final $Res Function(NewLegInput) _then;

/// Create a copy of NewLegInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? optionType = null,Object? strike = null,Object? expiration = null,Object? contracts = null,Object? openedAt = null,Object? openCreditPerShare = null,Object? ruleProfileVersionId = null,Object? ivAtOpen = freezed,Object? ivRankAtOpen = freezed,Object? deltaAtOpen = freezed,Object? underlyingPriceAtOpen = freezed,Object? openFee = freezed,Object? acceptsAssignment = null,}) {
  return _then(_self.copyWith(
optionType: null == optionType ? _self.optionType : optionType // ignore: cast_nullable_to_non_nullable
as OptionType,strike: null == strike ? _self.strike : strike // ignore: cast_nullable_to_non_nullable
as Decimal,expiration: null == expiration ? _self.expiration : expiration // ignore: cast_nullable_to_non_nullable
as DateTime,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,openedAt: null == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as DateTime,openCreditPerShare: null == openCreditPerShare ? _self.openCreditPerShare : openCreditPerShare // ignore: cast_nullable_to_non_nullable
as Decimal,ruleProfileVersionId: null == ruleProfileVersionId ? _self.ruleProfileVersionId : ruleProfileVersionId // ignore: cast_nullable_to_non_nullable
as String,ivAtOpen: freezed == ivAtOpen ? _self.ivAtOpen : ivAtOpen // ignore: cast_nullable_to_non_nullable
as double?,ivRankAtOpen: freezed == ivRankAtOpen ? _self.ivRankAtOpen : ivRankAtOpen // ignore: cast_nullable_to_non_nullable
as double?,deltaAtOpen: freezed == deltaAtOpen ? _self.deltaAtOpen : deltaAtOpen // ignore: cast_nullable_to_non_nullable
as double?,underlyingPriceAtOpen: freezed == underlyingPriceAtOpen ? _self.underlyingPriceAtOpen : underlyingPriceAtOpen // ignore: cast_nullable_to_non_nullable
as Decimal?,openFee: freezed == openFee ? _self.openFee : openFee // ignore: cast_nullable_to_non_nullable
as Decimal?,acceptsAssignment: null == acceptsAssignment ? _self.acceptsAssignment : acceptsAssignment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [NewLegInput].
extension NewLegInputPatterns on NewLegInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewLegInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewLegInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewLegInput value)  $default,){
final _that = this;
switch (_that) {
case _NewLegInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewLegInput value)?  $default,){
final _that = this;
switch (_that) {
case _NewLegInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OptionType optionType,  Decimal strike,  DateTime expiration,  int contracts,  DateTime openedAt,  Decimal openCreditPerShare,  String ruleProfileVersionId,  double? ivAtOpen,  double? ivRankAtOpen,  double? deltaAtOpen,  Decimal? underlyingPriceAtOpen,  Decimal? openFee,  bool acceptsAssignment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewLegInput() when $default != null:
return $default(_that.optionType,_that.strike,_that.expiration,_that.contracts,_that.openedAt,_that.openCreditPerShare,_that.ruleProfileVersionId,_that.ivAtOpen,_that.ivRankAtOpen,_that.deltaAtOpen,_that.underlyingPriceAtOpen,_that.openFee,_that.acceptsAssignment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OptionType optionType,  Decimal strike,  DateTime expiration,  int contracts,  DateTime openedAt,  Decimal openCreditPerShare,  String ruleProfileVersionId,  double? ivAtOpen,  double? ivRankAtOpen,  double? deltaAtOpen,  Decimal? underlyingPriceAtOpen,  Decimal? openFee,  bool acceptsAssignment)  $default,) {final _that = this;
switch (_that) {
case _NewLegInput():
return $default(_that.optionType,_that.strike,_that.expiration,_that.contracts,_that.openedAt,_that.openCreditPerShare,_that.ruleProfileVersionId,_that.ivAtOpen,_that.ivRankAtOpen,_that.deltaAtOpen,_that.underlyingPriceAtOpen,_that.openFee,_that.acceptsAssignment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OptionType optionType,  Decimal strike,  DateTime expiration,  int contracts,  DateTime openedAt,  Decimal openCreditPerShare,  String ruleProfileVersionId,  double? ivAtOpen,  double? ivRankAtOpen,  double? deltaAtOpen,  Decimal? underlyingPriceAtOpen,  Decimal? openFee,  bool acceptsAssignment)?  $default,) {final _that = this;
switch (_that) {
case _NewLegInput() when $default != null:
return $default(_that.optionType,_that.strike,_that.expiration,_that.contracts,_that.openedAt,_that.openCreditPerShare,_that.ruleProfileVersionId,_that.ivAtOpen,_that.ivRankAtOpen,_that.deltaAtOpen,_that.underlyingPriceAtOpen,_that.openFee,_that.acceptsAssignment);case _:
  return null;

}
}

}

/// @nodoc


class _NewLegInput implements NewLegInput {
  const _NewLegInput({required this.optionType, required this.strike, required this.expiration, required this.contracts, required this.openedAt, required this.openCreditPerShare, required this.ruleProfileVersionId, this.ivAtOpen, this.ivRankAtOpen, this.deltaAtOpen, this.underlyingPriceAtOpen, this.openFee, this.acceptsAssignment = true});
  

@override final  OptionType optionType;
@override final  Decimal strike;
@override final  DateTime expiration;
@override final  int contracts;
@override final  DateTime openedAt;
@override final  Decimal openCreditPerShare;
/// The `rule_profile_version` id this leg pins
/// (`<profileId>-v<n>`, see [Leg.ruleProfileVersionId]) — always a
/// version id, never a bare profile id, so the leg's rules are truthful
/// to the moment it opened even after later edits.
@override final  String ruleProfileVersionId;
@override final  double? ivAtOpen;
@override final  double? ivRankAtOpen;
@override final  double? deltaAtOpen;
@override final  Decimal? underlyingPriceAtOpen;
/// Total fee for opening this leg, in dollars — `null` means "not
/// recorded," never zero (Phase 15). Carried straight onto the created
/// [Leg].
@override final  Decimal? openFee;
/// Whether this leg's owner accepts assignment rather than rolling
/// (Phase 15/16 Gate 2). Defaults to `true` when the caller doesn't
/// pass one (S-094); an explicit value (e.g. `false`, inherited across
/// a roll per S-095/S-102) is never overwritten by the repository.
@override@JsonKey() final  bool acceptsAssignment;

/// Create a copy of NewLegInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewLegInputCopyWith<_NewLegInput> get copyWith => __$NewLegInputCopyWithImpl<_NewLegInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewLegInput&&(identical(other.optionType, optionType) || other.optionType == optionType)&&(identical(other.strike, strike) || other.strike == strike)&&(identical(other.expiration, expiration) || other.expiration == expiration)&&(identical(other.contracts, contracts) || other.contracts == contracts)&&(identical(other.openedAt, openedAt) || other.openedAt == openedAt)&&(identical(other.openCreditPerShare, openCreditPerShare) || other.openCreditPerShare == openCreditPerShare)&&(identical(other.ruleProfileVersionId, ruleProfileVersionId) || other.ruleProfileVersionId == ruleProfileVersionId)&&(identical(other.ivAtOpen, ivAtOpen) || other.ivAtOpen == ivAtOpen)&&(identical(other.ivRankAtOpen, ivRankAtOpen) || other.ivRankAtOpen == ivRankAtOpen)&&(identical(other.deltaAtOpen, deltaAtOpen) || other.deltaAtOpen == deltaAtOpen)&&(identical(other.underlyingPriceAtOpen, underlyingPriceAtOpen) || other.underlyingPriceAtOpen == underlyingPriceAtOpen)&&(identical(other.openFee, openFee) || other.openFee == openFee)&&(identical(other.acceptsAssignment, acceptsAssignment) || other.acceptsAssignment == acceptsAssignment));
}


@override
int get hashCode => Object.hash(runtimeType,optionType,strike,expiration,contracts,openedAt,openCreditPerShare,ruleProfileVersionId,ivAtOpen,ivRankAtOpen,deltaAtOpen,underlyingPriceAtOpen,openFee,acceptsAssignment);

@override
String toString() {
  return 'NewLegInput(optionType: $optionType, strike: $strike, expiration: $expiration, contracts: $contracts, openedAt: $openedAt, openCreditPerShare: $openCreditPerShare, ruleProfileVersionId: $ruleProfileVersionId, ivAtOpen: $ivAtOpen, ivRankAtOpen: $ivRankAtOpen, deltaAtOpen: $deltaAtOpen, underlyingPriceAtOpen: $underlyingPriceAtOpen, openFee: $openFee, acceptsAssignment: $acceptsAssignment)';
}


}

/// @nodoc
abstract mixin class _$NewLegInputCopyWith<$Res> implements $NewLegInputCopyWith<$Res> {
  factory _$NewLegInputCopyWith(_NewLegInput value, $Res Function(_NewLegInput) _then) = __$NewLegInputCopyWithImpl;
@override @useResult
$Res call({
 OptionType optionType, Decimal strike, DateTime expiration, int contracts, DateTime openedAt, Decimal openCreditPerShare, String ruleProfileVersionId, double? ivAtOpen, double? ivRankAtOpen, double? deltaAtOpen, Decimal? underlyingPriceAtOpen, Decimal? openFee, bool acceptsAssignment
});




}
/// @nodoc
class __$NewLegInputCopyWithImpl<$Res>
    implements _$NewLegInputCopyWith<$Res> {
  __$NewLegInputCopyWithImpl(this._self, this._then);

  final _NewLegInput _self;
  final $Res Function(_NewLegInput) _then;

/// Create a copy of NewLegInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? optionType = null,Object? strike = null,Object? expiration = null,Object? contracts = null,Object? openedAt = null,Object? openCreditPerShare = null,Object? ruleProfileVersionId = null,Object? ivAtOpen = freezed,Object? ivRankAtOpen = freezed,Object? deltaAtOpen = freezed,Object? underlyingPriceAtOpen = freezed,Object? openFee = freezed,Object? acceptsAssignment = null,}) {
  return _then(_NewLegInput(
optionType: null == optionType ? _self.optionType : optionType // ignore: cast_nullable_to_non_nullable
as OptionType,strike: null == strike ? _self.strike : strike // ignore: cast_nullable_to_non_nullable
as Decimal,expiration: null == expiration ? _self.expiration : expiration // ignore: cast_nullable_to_non_nullable
as DateTime,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,openedAt: null == openedAt ? _self.openedAt : openedAt // ignore: cast_nullable_to_non_nullable
as DateTime,openCreditPerShare: null == openCreditPerShare ? _self.openCreditPerShare : openCreditPerShare // ignore: cast_nullable_to_non_nullable
as Decimal,ruleProfileVersionId: null == ruleProfileVersionId ? _self.ruleProfileVersionId : ruleProfileVersionId // ignore: cast_nullable_to_non_nullable
as String,ivAtOpen: freezed == ivAtOpen ? _self.ivAtOpen : ivAtOpen // ignore: cast_nullable_to_non_nullable
as double?,ivRankAtOpen: freezed == ivRankAtOpen ? _self.ivRankAtOpen : ivRankAtOpen // ignore: cast_nullable_to_non_nullable
as double?,deltaAtOpen: freezed == deltaAtOpen ? _self.deltaAtOpen : deltaAtOpen // ignore: cast_nullable_to_non_nullable
as double?,underlyingPriceAtOpen: freezed == underlyingPriceAtOpen ? _self.underlyingPriceAtOpen : underlyingPriceAtOpen // ignore: cast_nullable_to_non_nullable
as Decimal?,openFee: freezed == openFee ? _self.openFee : openFee // ignore: cast_nullable_to_non_nullable
as Decimal?,acceptsAssignment: null == acceptsAssignment ? _self.acceptsAssignment : acceptsAssignment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$NewRuleProfileVersionInput {

 double get profitTargetPct; double get assignThreshold; double get baseRollBand; double get midIvRollBand; double get highIvRollBand; double get midIvCutoff; double get highIvCutoff; int get tailDteDays; Decimal get tailExtrinsicThreshold; double get minIvRank; double get minAnnualisedYield; int get targetDteMin; int get targetDteMax; double get targetDelta;
/// Create a copy of NewRuleProfileVersionInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewRuleProfileVersionInputCopyWith<NewRuleProfileVersionInput> get copyWith => _$NewRuleProfileVersionInputCopyWithImpl<NewRuleProfileVersionInput>(this as NewRuleProfileVersionInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewRuleProfileVersionInput&&(identical(other.profitTargetPct, profitTargetPct) || other.profitTargetPct == profitTargetPct)&&(identical(other.assignThreshold, assignThreshold) || other.assignThreshold == assignThreshold)&&(identical(other.baseRollBand, baseRollBand) || other.baseRollBand == baseRollBand)&&(identical(other.midIvRollBand, midIvRollBand) || other.midIvRollBand == midIvRollBand)&&(identical(other.highIvRollBand, highIvRollBand) || other.highIvRollBand == highIvRollBand)&&(identical(other.midIvCutoff, midIvCutoff) || other.midIvCutoff == midIvCutoff)&&(identical(other.highIvCutoff, highIvCutoff) || other.highIvCutoff == highIvCutoff)&&(identical(other.tailDteDays, tailDteDays) || other.tailDteDays == tailDteDays)&&(identical(other.tailExtrinsicThreshold, tailExtrinsicThreshold) || other.tailExtrinsicThreshold == tailExtrinsicThreshold)&&(identical(other.minIvRank, minIvRank) || other.minIvRank == minIvRank)&&(identical(other.minAnnualisedYield, minAnnualisedYield) || other.minAnnualisedYield == minAnnualisedYield)&&(identical(other.targetDteMin, targetDteMin) || other.targetDteMin == targetDteMin)&&(identical(other.targetDteMax, targetDteMax) || other.targetDteMax == targetDteMax)&&(identical(other.targetDelta, targetDelta) || other.targetDelta == targetDelta));
}


@override
int get hashCode => Object.hash(runtimeType,profitTargetPct,assignThreshold,baseRollBand,midIvRollBand,highIvRollBand,midIvCutoff,highIvCutoff,tailDteDays,tailExtrinsicThreshold,minIvRank,minAnnualisedYield,targetDteMin,targetDteMax,targetDelta);

@override
String toString() {
  return 'NewRuleProfileVersionInput(profitTargetPct: $profitTargetPct, assignThreshold: $assignThreshold, baseRollBand: $baseRollBand, midIvRollBand: $midIvRollBand, highIvRollBand: $highIvRollBand, midIvCutoff: $midIvCutoff, highIvCutoff: $highIvCutoff, tailDteDays: $tailDteDays, tailExtrinsicThreshold: $tailExtrinsicThreshold, minIvRank: $minIvRank, minAnnualisedYield: $minAnnualisedYield, targetDteMin: $targetDteMin, targetDteMax: $targetDteMax, targetDelta: $targetDelta)';
}


}

/// @nodoc
abstract mixin class $NewRuleProfileVersionInputCopyWith<$Res>  {
  factory $NewRuleProfileVersionInputCopyWith(NewRuleProfileVersionInput value, $Res Function(NewRuleProfileVersionInput) _then) = _$NewRuleProfileVersionInputCopyWithImpl;
@useResult
$Res call({
 double profitTargetPct, double assignThreshold, double baseRollBand, double midIvRollBand, double highIvRollBand, double midIvCutoff, double highIvCutoff, int tailDteDays, Decimal tailExtrinsicThreshold, double minIvRank, double minAnnualisedYield, int targetDteMin, int targetDteMax, double targetDelta
});




}
/// @nodoc
class _$NewRuleProfileVersionInputCopyWithImpl<$Res>
    implements $NewRuleProfileVersionInputCopyWith<$Res> {
  _$NewRuleProfileVersionInputCopyWithImpl(this._self, this._then);

  final NewRuleProfileVersionInput _self;
  final $Res Function(NewRuleProfileVersionInput) _then;

/// Create a copy of NewRuleProfileVersionInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profitTargetPct = null,Object? assignThreshold = null,Object? baseRollBand = null,Object? midIvRollBand = null,Object? highIvRollBand = null,Object? midIvCutoff = null,Object? highIvCutoff = null,Object? tailDteDays = null,Object? tailExtrinsicThreshold = null,Object? minIvRank = null,Object? minAnnualisedYield = null,Object? targetDteMin = null,Object? targetDteMax = null,Object? targetDelta = null,}) {
  return _then(_self.copyWith(
profitTargetPct: null == profitTargetPct ? _self.profitTargetPct : profitTargetPct // ignore: cast_nullable_to_non_nullable
as double,assignThreshold: null == assignThreshold ? _self.assignThreshold : assignThreshold // ignore: cast_nullable_to_non_nullable
as double,baseRollBand: null == baseRollBand ? _self.baseRollBand : baseRollBand // ignore: cast_nullable_to_non_nullable
as double,midIvRollBand: null == midIvRollBand ? _self.midIvRollBand : midIvRollBand // ignore: cast_nullable_to_non_nullable
as double,highIvRollBand: null == highIvRollBand ? _self.highIvRollBand : highIvRollBand // ignore: cast_nullable_to_non_nullable
as double,midIvCutoff: null == midIvCutoff ? _self.midIvCutoff : midIvCutoff // ignore: cast_nullable_to_non_nullable
as double,highIvCutoff: null == highIvCutoff ? _self.highIvCutoff : highIvCutoff // ignore: cast_nullable_to_non_nullable
as double,tailDteDays: null == tailDteDays ? _self.tailDteDays : tailDteDays // ignore: cast_nullable_to_non_nullable
as int,tailExtrinsicThreshold: null == tailExtrinsicThreshold ? _self.tailExtrinsicThreshold : tailExtrinsicThreshold // ignore: cast_nullable_to_non_nullable
as Decimal,minIvRank: null == minIvRank ? _self.minIvRank : minIvRank // ignore: cast_nullable_to_non_nullable
as double,minAnnualisedYield: null == minAnnualisedYield ? _self.minAnnualisedYield : minAnnualisedYield // ignore: cast_nullable_to_non_nullable
as double,targetDteMin: null == targetDteMin ? _self.targetDteMin : targetDteMin // ignore: cast_nullable_to_non_nullable
as int,targetDteMax: null == targetDteMax ? _self.targetDteMax : targetDteMax // ignore: cast_nullable_to_non_nullable
as int,targetDelta: null == targetDelta ? _self.targetDelta : targetDelta // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [NewRuleProfileVersionInput].
extension NewRuleProfileVersionInputPatterns on NewRuleProfileVersionInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewRuleProfileVersionInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewRuleProfileVersionInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewRuleProfileVersionInput value)  $default,){
final _that = this;
switch (_that) {
case _NewRuleProfileVersionInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewRuleProfileVersionInput value)?  $default,){
final _that = this;
switch (_that) {
case _NewRuleProfileVersionInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double profitTargetPct,  double assignThreshold,  double baseRollBand,  double midIvRollBand,  double highIvRollBand,  double midIvCutoff,  double highIvCutoff,  int tailDteDays,  Decimal tailExtrinsicThreshold,  double minIvRank,  double minAnnualisedYield,  int targetDteMin,  int targetDteMax,  double targetDelta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewRuleProfileVersionInput() when $default != null:
return $default(_that.profitTargetPct,_that.assignThreshold,_that.baseRollBand,_that.midIvRollBand,_that.highIvRollBand,_that.midIvCutoff,_that.highIvCutoff,_that.tailDteDays,_that.tailExtrinsicThreshold,_that.minIvRank,_that.minAnnualisedYield,_that.targetDteMin,_that.targetDteMax,_that.targetDelta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double profitTargetPct,  double assignThreshold,  double baseRollBand,  double midIvRollBand,  double highIvRollBand,  double midIvCutoff,  double highIvCutoff,  int tailDteDays,  Decimal tailExtrinsicThreshold,  double minIvRank,  double minAnnualisedYield,  int targetDteMin,  int targetDteMax,  double targetDelta)  $default,) {final _that = this;
switch (_that) {
case _NewRuleProfileVersionInput():
return $default(_that.profitTargetPct,_that.assignThreshold,_that.baseRollBand,_that.midIvRollBand,_that.highIvRollBand,_that.midIvCutoff,_that.highIvCutoff,_that.tailDteDays,_that.tailExtrinsicThreshold,_that.minIvRank,_that.minAnnualisedYield,_that.targetDteMin,_that.targetDteMax,_that.targetDelta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double profitTargetPct,  double assignThreshold,  double baseRollBand,  double midIvRollBand,  double highIvRollBand,  double midIvCutoff,  double highIvCutoff,  int tailDteDays,  Decimal tailExtrinsicThreshold,  double minIvRank,  double minAnnualisedYield,  int targetDteMin,  int targetDteMax,  double targetDelta)?  $default,) {final _that = this;
switch (_that) {
case _NewRuleProfileVersionInput() when $default != null:
return $default(_that.profitTargetPct,_that.assignThreshold,_that.baseRollBand,_that.midIvRollBand,_that.highIvRollBand,_that.midIvCutoff,_that.highIvCutoff,_that.tailDteDays,_that.tailExtrinsicThreshold,_that.minIvRank,_that.minAnnualisedYield,_that.targetDteMin,_that.targetDteMax,_that.targetDelta);case _:
  return null;

}
}

}

/// @nodoc


class _NewRuleProfileVersionInput implements NewRuleProfileVersionInput {
  const _NewRuleProfileVersionInput({required this.profitTargetPct, required this.assignThreshold, required this.baseRollBand, required this.midIvRollBand, required this.highIvRollBand, required this.midIvCutoff, required this.highIvCutoff, required this.tailDteDays, required this.tailExtrinsicThreshold, required this.minIvRank, required this.minAnnualisedYield, required this.targetDteMin, required this.targetDteMax, required this.targetDelta});
  

@override final  double profitTargetPct;
@override final  double assignThreshold;
@override final  double baseRollBand;
@override final  double midIvRollBand;
@override final  double highIvRollBand;
@override final  double midIvCutoff;
@override final  double highIvCutoff;
@override final  int tailDteDays;
@override final  Decimal tailExtrinsicThreshold;
@override final  double minIvRank;
@override final  double minAnnualisedYield;
@override final  int targetDteMin;
@override final  int targetDteMax;
@override final  double targetDelta;

/// Create a copy of NewRuleProfileVersionInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewRuleProfileVersionInputCopyWith<_NewRuleProfileVersionInput> get copyWith => __$NewRuleProfileVersionInputCopyWithImpl<_NewRuleProfileVersionInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewRuleProfileVersionInput&&(identical(other.profitTargetPct, profitTargetPct) || other.profitTargetPct == profitTargetPct)&&(identical(other.assignThreshold, assignThreshold) || other.assignThreshold == assignThreshold)&&(identical(other.baseRollBand, baseRollBand) || other.baseRollBand == baseRollBand)&&(identical(other.midIvRollBand, midIvRollBand) || other.midIvRollBand == midIvRollBand)&&(identical(other.highIvRollBand, highIvRollBand) || other.highIvRollBand == highIvRollBand)&&(identical(other.midIvCutoff, midIvCutoff) || other.midIvCutoff == midIvCutoff)&&(identical(other.highIvCutoff, highIvCutoff) || other.highIvCutoff == highIvCutoff)&&(identical(other.tailDteDays, tailDteDays) || other.tailDteDays == tailDteDays)&&(identical(other.tailExtrinsicThreshold, tailExtrinsicThreshold) || other.tailExtrinsicThreshold == tailExtrinsicThreshold)&&(identical(other.minIvRank, minIvRank) || other.minIvRank == minIvRank)&&(identical(other.minAnnualisedYield, minAnnualisedYield) || other.minAnnualisedYield == minAnnualisedYield)&&(identical(other.targetDteMin, targetDteMin) || other.targetDteMin == targetDteMin)&&(identical(other.targetDteMax, targetDteMax) || other.targetDteMax == targetDteMax)&&(identical(other.targetDelta, targetDelta) || other.targetDelta == targetDelta));
}


@override
int get hashCode => Object.hash(runtimeType,profitTargetPct,assignThreshold,baseRollBand,midIvRollBand,highIvRollBand,midIvCutoff,highIvCutoff,tailDteDays,tailExtrinsicThreshold,minIvRank,minAnnualisedYield,targetDteMin,targetDteMax,targetDelta);

@override
String toString() {
  return 'NewRuleProfileVersionInput(profitTargetPct: $profitTargetPct, assignThreshold: $assignThreshold, baseRollBand: $baseRollBand, midIvRollBand: $midIvRollBand, highIvRollBand: $highIvRollBand, midIvCutoff: $midIvCutoff, highIvCutoff: $highIvCutoff, tailDteDays: $tailDteDays, tailExtrinsicThreshold: $tailExtrinsicThreshold, minIvRank: $minIvRank, minAnnualisedYield: $minAnnualisedYield, targetDteMin: $targetDteMin, targetDteMax: $targetDteMax, targetDelta: $targetDelta)';
}


}

/// @nodoc
abstract mixin class _$NewRuleProfileVersionInputCopyWith<$Res> implements $NewRuleProfileVersionInputCopyWith<$Res> {
  factory _$NewRuleProfileVersionInputCopyWith(_NewRuleProfileVersionInput value, $Res Function(_NewRuleProfileVersionInput) _then) = __$NewRuleProfileVersionInputCopyWithImpl;
@override @useResult
$Res call({
 double profitTargetPct, double assignThreshold, double baseRollBand, double midIvRollBand, double highIvRollBand, double midIvCutoff, double highIvCutoff, int tailDteDays, Decimal tailExtrinsicThreshold, double minIvRank, double minAnnualisedYield, int targetDteMin, int targetDteMax, double targetDelta
});




}
/// @nodoc
class __$NewRuleProfileVersionInputCopyWithImpl<$Res>
    implements _$NewRuleProfileVersionInputCopyWith<$Res> {
  __$NewRuleProfileVersionInputCopyWithImpl(this._self, this._then);

  final _NewRuleProfileVersionInput _self;
  final $Res Function(_NewRuleProfileVersionInput) _then;

/// Create a copy of NewRuleProfileVersionInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profitTargetPct = null,Object? assignThreshold = null,Object? baseRollBand = null,Object? midIvRollBand = null,Object? highIvRollBand = null,Object? midIvCutoff = null,Object? highIvCutoff = null,Object? tailDteDays = null,Object? tailExtrinsicThreshold = null,Object? minIvRank = null,Object? minAnnualisedYield = null,Object? targetDteMin = null,Object? targetDteMax = null,Object? targetDelta = null,}) {
  return _then(_NewRuleProfileVersionInput(
profitTargetPct: null == profitTargetPct ? _self.profitTargetPct : profitTargetPct // ignore: cast_nullable_to_non_nullable
as double,assignThreshold: null == assignThreshold ? _self.assignThreshold : assignThreshold // ignore: cast_nullable_to_non_nullable
as double,baseRollBand: null == baseRollBand ? _self.baseRollBand : baseRollBand // ignore: cast_nullable_to_non_nullable
as double,midIvRollBand: null == midIvRollBand ? _self.midIvRollBand : midIvRollBand // ignore: cast_nullable_to_non_nullable
as double,highIvRollBand: null == highIvRollBand ? _self.highIvRollBand : highIvRollBand // ignore: cast_nullable_to_non_nullable
as double,midIvCutoff: null == midIvCutoff ? _self.midIvCutoff : midIvCutoff // ignore: cast_nullable_to_non_nullable
as double,highIvCutoff: null == highIvCutoff ? _self.highIvCutoff : highIvCutoff // ignore: cast_nullable_to_non_nullable
as double,tailDteDays: null == tailDteDays ? _self.tailDteDays : tailDteDays // ignore: cast_nullable_to_non_nullable
as int,tailExtrinsicThreshold: null == tailExtrinsicThreshold ? _self.tailExtrinsicThreshold : tailExtrinsicThreshold // ignore: cast_nullable_to_non_nullable
as Decimal,minIvRank: null == minIvRank ? _self.minIvRank : minIvRank // ignore: cast_nullable_to_non_nullable
as double,minAnnualisedYield: null == minAnnualisedYield ? _self.minAnnualisedYield : minAnnualisedYield // ignore: cast_nullable_to_non_nullable
as double,targetDteMin: null == targetDteMin ? _self.targetDteMin : targetDteMin // ignore: cast_nullable_to_non_nullable
as int,targetDteMax: null == targetDteMax ? _self.targetDteMax : targetDteMax // ignore: cast_nullable_to_non_nullable
as int,targetDelta: null == targetDelta ? _self.targetDelta : targetDelta // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$NewSnapshotInput {

 String get legId; DateTime get takenAt; Decimal get optionMark; Decimal get underlyingPrice; double get deltaAsEntered; DeltaConvention get deltaConvention; double? get gamma; double? get theta; double? get vega; double? get iv; int? get openInterest; int? get volume;
/// Create a copy of NewSnapshotInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewSnapshotInputCopyWith<NewSnapshotInput> get copyWith => _$NewSnapshotInputCopyWithImpl<NewSnapshotInput>(this as NewSnapshotInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewSnapshotInput&&(identical(other.legId, legId) || other.legId == legId)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt)&&(identical(other.optionMark, optionMark) || other.optionMark == optionMark)&&(identical(other.underlyingPrice, underlyingPrice) || other.underlyingPrice == underlyingPrice)&&(identical(other.deltaAsEntered, deltaAsEntered) || other.deltaAsEntered == deltaAsEntered)&&(identical(other.deltaConvention, deltaConvention) || other.deltaConvention == deltaConvention)&&(identical(other.gamma, gamma) || other.gamma == gamma)&&(identical(other.theta, theta) || other.theta == theta)&&(identical(other.vega, vega) || other.vega == vega)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.openInterest, openInterest) || other.openInterest == openInterest)&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode => Object.hash(runtimeType,legId,takenAt,optionMark,underlyingPrice,deltaAsEntered,deltaConvention,gamma,theta,vega,iv,openInterest,volume);

@override
String toString() {
  return 'NewSnapshotInput(legId: $legId, takenAt: $takenAt, optionMark: $optionMark, underlyingPrice: $underlyingPrice, deltaAsEntered: $deltaAsEntered, deltaConvention: $deltaConvention, gamma: $gamma, theta: $theta, vega: $vega, iv: $iv, openInterest: $openInterest, volume: $volume)';
}


}

/// @nodoc
abstract mixin class $NewSnapshotInputCopyWith<$Res>  {
  factory $NewSnapshotInputCopyWith(NewSnapshotInput value, $Res Function(NewSnapshotInput) _then) = _$NewSnapshotInputCopyWithImpl;
@useResult
$Res call({
 String legId, DateTime takenAt, Decimal optionMark, Decimal underlyingPrice, double deltaAsEntered, DeltaConvention deltaConvention, double? gamma, double? theta, double? vega, double? iv, int? openInterest, int? volume
});




}
/// @nodoc
class _$NewSnapshotInputCopyWithImpl<$Res>
    implements $NewSnapshotInputCopyWith<$Res> {
  _$NewSnapshotInputCopyWithImpl(this._self, this._then);

  final NewSnapshotInput _self;
  final $Res Function(NewSnapshotInput) _then;

/// Create a copy of NewSnapshotInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? legId = null,Object? takenAt = null,Object? optionMark = null,Object? underlyingPrice = null,Object? deltaAsEntered = null,Object? deltaConvention = null,Object? gamma = freezed,Object? theta = freezed,Object? vega = freezed,Object? iv = freezed,Object? openInterest = freezed,Object? volume = freezed,}) {
  return _then(_self.copyWith(
legId: null == legId ? _self.legId : legId // ignore: cast_nullable_to_non_nullable
as String,takenAt: null == takenAt ? _self.takenAt : takenAt // ignore: cast_nullable_to_non_nullable
as DateTime,optionMark: null == optionMark ? _self.optionMark : optionMark // ignore: cast_nullable_to_non_nullable
as Decimal,underlyingPrice: null == underlyingPrice ? _self.underlyingPrice : underlyingPrice // ignore: cast_nullable_to_non_nullable
as Decimal,deltaAsEntered: null == deltaAsEntered ? _self.deltaAsEntered : deltaAsEntered // ignore: cast_nullable_to_non_nullable
as double,deltaConvention: null == deltaConvention ? _self.deltaConvention : deltaConvention // ignore: cast_nullable_to_non_nullable
as DeltaConvention,gamma: freezed == gamma ? _self.gamma : gamma // ignore: cast_nullable_to_non_nullable
as double?,theta: freezed == theta ? _self.theta : theta // ignore: cast_nullable_to_non_nullable
as double?,vega: freezed == vega ? _self.vega : vega // ignore: cast_nullable_to_non_nullable
as double?,iv: freezed == iv ? _self.iv : iv // ignore: cast_nullable_to_non_nullable
as double?,openInterest: freezed == openInterest ? _self.openInterest : openInterest // ignore: cast_nullable_to_non_nullable
as int?,volume: freezed == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [NewSnapshotInput].
extension NewSnapshotInputPatterns on NewSnapshotInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewSnapshotInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewSnapshotInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewSnapshotInput value)  $default,){
final _that = this;
switch (_that) {
case _NewSnapshotInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewSnapshotInput value)?  $default,){
final _that = this;
switch (_that) {
case _NewSnapshotInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String legId,  DateTime takenAt,  Decimal optionMark,  Decimal underlyingPrice,  double deltaAsEntered,  DeltaConvention deltaConvention,  double? gamma,  double? theta,  double? vega,  double? iv,  int? openInterest,  int? volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewSnapshotInput() when $default != null:
return $default(_that.legId,_that.takenAt,_that.optionMark,_that.underlyingPrice,_that.deltaAsEntered,_that.deltaConvention,_that.gamma,_that.theta,_that.vega,_that.iv,_that.openInterest,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String legId,  DateTime takenAt,  Decimal optionMark,  Decimal underlyingPrice,  double deltaAsEntered,  DeltaConvention deltaConvention,  double? gamma,  double? theta,  double? vega,  double? iv,  int? openInterest,  int? volume)  $default,) {final _that = this;
switch (_that) {
case _NewSnapshotInput():
return $default(_that.legId,_that.takenAt,_that.optionMark,_that.underlyingPrice,_that.deltaAsEntered,_that.deltaConvention,_that.gamma,_that.theta,_that.vega,_that.iv,_that.openInterest,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String legId,  DateTime takenAt,  Decimal optionMark,  Decimal underlyingPrice,  double deltaAsEntered,  DeltaConvention deltaConvention,  double? gamma,  double? theta,  double? vega,  double? iv,  int? openInterest,  int? volume)?  $default,) {final _that = this;
switch (_that) {
case _NewSnapshotInput() when $default != null:
return $default(_that.legId,_that.takenAt,_that.optionMark,_that.underlyingPrice,_that.deltaAsEntered,_that.deltaConvention,_that.gamma,_that.theta,_that.vega,_that.iv,_that.openInterest,_that.volume);case _:
  return null;

}
}

}

/// @nodoc


class _NewSnapshotInput implements NewSnapshotInput {
  const _NewSnapshotInput({required this.legId, required this.takenAt, required this.optionMark, required this.underlyingPrice, required this.deltaAsEntered, required this.deltaConvention, this.gamma, this.theta, this.vega, this.iv, this.openInterest, this.volume});
  

@override final  String legId;
@override final  DateTime takenAt;
@override final  Decimal optionMark;
@override final  Decimal underlyingPrice;
@override final  double deltaAsEntered;
@override final  DeltaConvention deltaConvention;
@override final  double? gamma;
@override final  double? theta;
@override final  double? vega;
@override final  double? iv;
@override final  int? openInterest;
@override final  int? volume;

/// Create a copy of NewSnapshotInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewSnapshotInputCopyWith<_NewSnapshotInput> get copyWith => __$NewSnapshotInputCopyWithImpl<_NewSnapshotInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewSnapshotInput&&(identical(other.legId, legId) || other.legId == legId)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt)&&(identical(other.optionMark, optionMark) || other.optionMark == optionMark)&&(identical(other.underlyingPrice, underlyingPrice) || other.underlyingPrice == underlyingPrice)&&(identical(other.deltaAsEntered, deltaAsEntered) || other.deltaAsEntered == deltaAsEntered)&&(identical(other.deltaConvention, deltaConvention) || other.deltaConvention == deltaConvention)&&(identical(other.gamma, gamma) || other.gamma == gamma)&&(identical(other.theta, theta) || other.theta == theta)&&(identical(other.vega, vega) || other.vega == vega)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.openInterest, openInterest) || other.openInterest == openInterest)&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode => Object.hash(runtimeType,legId,takenAt,optionMark,underlyingPrice,deltaAsEntered,deltaConvention,gamma,theta,vega,iv,openInterest,volume);

@override
String toString() {
  return 'NewSnapshotInput(legId: $legId, takenAt: $takenAt, optionMark: $optionMark, underlyingPrice: $underlyingPrice, deltaAsEntered: $deltaAsEntered, deltaConvention: $deltaConvention, gamma: $gamma, theta: $theta, vega: $vega, iv: $iv, openInterest: $openInterest, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$NewSnapshotInputCopyWith<$Res> implements $NewSnapshotInputCopyWith<$Res> {
  factory _$NewSnapshotInputCopyWith(_NewSnapshotInput value, $Res Function(_NewSnapshotInput) _then) = __$NewSnapshotInputCopyWithImpl;
@override @useResult
$Res call({
 String legId, DateTime takenAt, Decimal optionMark, Decimal underlyingPrice, double deltaAsEntered, DeltaConvention deltaConvention, double? gamma, double? theta, double? vega, double? iv, int? openInterest, int? volume
});




}
/// @nodoc
class __$NewSnapshotInputCopyWithImpl<$Res>
    implements _$NewSnapshotInputCopyWith<$Res> {
  __$NewSnapshotInputCopyWithImpl(this._self, this._then);

  final _NewSnapshotInput _self;
  final $Res Function(_NewSnapshotInput) _then;

/// Create a copy of NewSnapshotInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? legId = null,Object? takenAt = null,Object? optionMark = null,Object? underlyingPrice = null,Object? deltaAsEntered = null,Object? deltaConvention = null,Object? gamma = freezed,Object? theta = freezed,Object? vega = freezed,Object? iv = freezed,Object? openInterest = freezed,Object? volume = freezed,}) {
  return _then(_NewSnapshotInput(
legId: null == legId ? _self.legId : legId // ignore: cast_nullable_to_non_nullable
as String,takenAt: null == takenAt ? _self.takenAt : takenAt // ignore: cast_nullable_to_non_nullable
as DateTime,optionMark: null == optionMark ? _self.optionMark : optionMark // ignore: cast_nullable_to_non_nullable
as Decimal,underlyingPrice: null == underlyingPrice ? _self.underlyingPrice : underlyingPrice // ignore: cast_nullable_to_non_nullable
as Decimal,deltaAsEntered: null == deltaAsEntered ? _self.deltaAsEntered : deltaAsEntered // ignore: cast_nullable_to_non_nullable
as double,deltaConvention: null == deltaConvention ? _self.deltaConvention : deltaConvention // ignore: cast_nullable_to_non_nullable
as DeltaConvention,gamma: freezed == gamma ? _self.gamma : gamma // ignore: cast_nullable_to_non_nullable
as double?,theta: freezed == theta ? _self.theta : theta // ignore: cast_nullable_to_non_nullable
as double?,vega: freezed == vega ? _self.vega : vega // ignore: cast_nullable_to_non_nullable
as double?,iv: freezed == iv ? _self.iv : iv // ignore: cast_nullable_to_non_nullable
as double?,openInterest: freezed == openInterest ? _self.openInterest : openInterest // ignore: cast_nullable_to_non_nullable
as int?,volume: freezed == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$NewShareLotInput {

 DateTime get assignedAt; Decimal get assignmentStrike; int get contracts;
/// Create a copy of NewShareLotInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NewShareLotInputCopyWith<NewShareLotInput> get copyWith => _$NewShareLotInputCopyWithImpl<NewShareLotInput>(this as NewShareLotInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NewShareLotInput&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.assignmentStrike, assignmentStrike) || other.assignmentStrike == assignmentStrike)&&(identical(other.contracts, contracts) || other.contracts == contracts));
}


@override
int get hashCode => Object.hash(runtimeType,assignedAt,assignmentStrike,contracts);

@override
String toString() {
  return 'NewShareLotInput(assignedAt: $assignedAt, assignmentStrike: $assignmentStrike, contracts: $contracts)';
}


}

/// @nodoc
abstract mixin class $NewShareLotInputCopyWith<$Res>  {
  factory $NewShareLotInputCopyWith(NewShareLotInput value, $Res Function(NewShareLotInput) _then) = _$NewShareLotInputCopyWithImpl;
@useResult
$Res call({
 DateTime assignedAt, Decimal assignmentStrike, int contracts
});




}
/// @nodoc
class _$NewShareLotInputCopyWithImpl<$Res>
    implements $NewShareLotInputCopyWith<$Res> {
  _$NewShareLotInputCopyWithImpl(this._self, this._then);

  final NewShareLotInput _self;
  final $Res Function(NewShareLotInput) _then;

/// Create a copy of NewShareLotInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assignedAt = null,Object? assignmentStrike = null,Object? contracts = null,}) {
  return _then(_self.copyWith(
assignedAt: null == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assignmentStrike: null == assignmentStrike ? _self.assignmentStrike : assignmentStrike // ignore: cast_nullable_to_non_nullable
as Decimal,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [NewShareLotInput].
extension NewShareLotInputPatterns on NewShareLotInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NewShareLotInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NewShareLotInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NewShareLotInput value)  $default,){
final _that = this;
switch (_that) {
case _NewShareLotInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NewShareLotInput value)?  $default,){
final _that = this;
switch (_that) {
case _NewShareLotInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime assignedAt,  Decimal assignmentStrike,  int contracts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NewShareLotInput() when $default != null:
return $default(_that.assignedAt,_that.assignmentStrike,_that.contracts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime assignedAt,  Decimal assignmentStrike,  int contracts)  $default,) {final _that = this;
switch (_that) {
case _NewShareLotInput():
return $default(_that.assignedAt,_that.assignmentStrike,_that.contracts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime assignedAt,  Decimal assignmentStrike,  int contracts)?  $default,) {final _that = this;
switch (_that) {
case _NewShareLotInput() when $default != null:
return $default(_that.assignedAt,_that.assignmentStrike,_that.contracts);case _:
  return null;

}
}

}

/// @nodoc


class _NewShareLotInput implements NewShareLotInput {
  const _NewShareLotInput({required this.assignedAt, required this.assignmentStrike, required this.contracts});
  

@override final  DateTime assignedAt;
@override final  Decimal assignmentStrike;
@override final  int contracts;

/// Create a copy of NewShareLotInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NewShareLotInputCopyWith<_NewShareLotInput> get copyWith => __$NewShareLotInputCopyWithImpl<_NewShareLotInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NewShareLotInput&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.assignmentStrike, assignmentStrike) || other.assignmentStrike == assignmentStrike)&&(identical(other.contracts, contracts) || other.contracts == contracts));
}


@override
int get hashCode => Object.hash(runtimeType,assignedAt,assignmentStrike,contracts);

@override
String toString() {
  return 'NewShareLotInput(assignedAt: $assignedAt, assignmentStrike: $assignmentStrike, contracts: $contracts)';
}


}

/// @nodoc
abstract mixin class _$NewShareLotInputCopyWith<$Res> implements $NewShareLotInputCopyWith<$Res> {
  factory _$NewShareLotInputCopyWith(_NewShareLotInput value, $Res Function(_NewShareLotInput) _then) = __$NewShareLotInputCopyWithImpl;
@override @useResult
$Res call({
 DateTime assignedAt, Decimal assignmentStrike, int contracts
});




}
/// @nodoc
class __$NewShareLotInputCopyWithImpl<$Res>
    implements _$NewShareLotInputCopyWith<$Res> {
  __$NewShareLotInputCopyWithImpl(this._self, this._then);

  final _NewShareLotInput _self;
  final $Res Function(_NewShareLotInput) _then;

/// Create a copy of NewShareLotInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assignedAt = null,Object? assignmentStrike = null,Object? contracts = null,}) {
  return _then(_NewShareLotInput(
assignedAt: null == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assignmentStrike: null == assignmentStrike ? _self.assignmentStrike : assignmentStrike // ignore: cast_nullable_to_non_nullable
as Decimal,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
