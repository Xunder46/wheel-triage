// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rule_profile_version_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RuleProfileVersionData {

 String get id; String get profileId; int get version; DateTime get effectiveAt; double get profitTargetPct; double get assignThreshold; double get baseRollBand; double get midIvRollBand; double get highIvRollBand; double get midIvCutoff; double get highIvCutoff; int get tailDteDays;@DecimalJsonConverter() Decimal get tailExtrinsicThreshold; double get minIvRank; double get minAnnualisedYield; int get targetDteMin; int get targetDteMax; double get targetDelta;
/// Create a copy of RuleProfileVersionData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleProfileVersionDataCopyWith<RuleProfileVersionData> get copyWith => _$RuleProfileVersionDataCopyWithImpl<RuleProfileVersionData>(this as RuleProfileVersionData, _$identity);

  /// Serializes this RuleProfileVersionData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleProfileVersionData&&(identical(other.id, id) || other.id == id)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.version, version) || other.version == version)&&(identical(other.effectiveAt, effectiveAt) || other.effectiveAt == effectiveAt)&&(identical(other.profitTargetPct, profitTargetPct) || other.profitTargetPct == profitTargetPct)&&(identical(other.assignThreshold, assignThreshold) || other.assignThreshold == assignThreshold)&&(identical(other.baseRollBand, baseRollBand) || other.baseRollBand == baseRollBand)&&(identical(other.midIvRollBand, midIvRollBand) || other.midIvRollBand == midIvRollBand)&&(identical(other.highIvRollBand, highIvRollBand) || other.highIvRollBand == highIvRollBand)&&(identical(other.midIvCutoff, midIvCutoff) || other.midIvCutoff == midIvCutoff)&&(identical(other.highIvCutoff, highIvCutoff) || other.highIvCutoff == highIvCutoff)&&(identical(other.tailDteDays, tailDteDays) || other.tailDteDays == tailDteDays)&&(identical(other.tailExtrinsicThreshold, tailExtrinsicThreshold) || other.tailExtrinsicThreshold == tailExtrinsicThreshold)&&(identical(other.minIvRank, minIvRank) || other.minIvRank == minIvRank)&&(identical(other.minAnnualisedYield, minAnnualisedYield) || other.minAnnualisedYield == minAnnualisedYield)&&(identical(other.targetDteMin, targetDteMin) || other.targetDteMin == targetDteMin)&&(identical(other.targetDteMax, targetDteMax) || other.targetDteMax == targetDteMax)&&(identical(other.targetDelta, targetDelta) || other.targetDelta == targetDelta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,profileId,version,effectiveAt,profitTargetPct,assignThreshold,baseRollBand,midIvRollBand,highIvRollBand,midIvCutoff,highIvCutoff,tailDteDays,tailExtrinsicThreshold,minIvRank,minAnnualisedYield,targetDteMin,targetDteMax,targetDelta);

@override
String toString() {
  return 'RuleProfileVersionData(id: $id, profileId: $profileId, version: $version, effectiveAt: $effectiveAt, profitTargetPct: $profitTargetPct, assignThreshold: $assignThreshold, baseRollBand: $baseRollBand, midIvRollBand: $midIvRollBand, highIvRollBand: $highIvRollBand, midIvCutoff: $midIvCutoff, highIvCutoff: $highIvCutoff, tailDteDays: $tailDteDays, tailExtrinsicThreshold: $tailExtrinsicThreshold, minIvRank: $minIvRank, minAnnualisedYield: $minAnnualisedYield, targetDteMin: $targetDteMin, targetDteMax: $targetDteMax, targetDelta: $targetDelta)';
}


}

/// @nodoc
abstract mixin class $RuleProfileVersionDataCopyWith<$Res>  {
  factory $RuleProfileVersionDataCopyWith(RuleProfileVersionData value, $Res Function(RuleProfileVersionData) _then) = _$RuleProfileVersionDataCopyWithImpl;
@useResult
$Res call({
 String id, String profileId, int version, DateTime effectiveAt, double profitTargetPct, double assignThreshold, double baseRollBand, double midIvRollBand, double highIvRollBand, double midIvCutoff, double highIvCutoff, int tailDteDays,@DecimalJsonConverter() Decimal tailExtrinsicThreshold, double minIvRank, double minAnnualisedYield, int targetDteMin, int targetDteMax, double targetDelta
});




}
/// @nodoc
class _$RuleProfileVersionDataCopyWithImpl<$Res>
    implements $RuleProfileVersionDataCopyWith<$Res> {
  _$RuleProfileVersionDataCopyWithImpl(this._self, this._then);

  final RuleProfileVersionData _self;
  final $Res Function(RuleProfileVersionData) _then;

/// Create a copy of RuleProfileVersionData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? profileId = null,Object? version = null,Object? effectiveAt = null,Object? profitTargetPct = null,Object? assignThreshold = null,Object? baseRollBand = null,Object? midIvRollBand = null,Object? highIvRollBand = null,Object? midIvCutoff = null,Object? highIvCutoff = null,Object? tailDteDays = null,Object? tailExtrinsicThreshold = null,Object? minIvRank = null,Object? minAnnualisedYield = null,Object? targetDteMin = null,Object? targetDteMax = null,Object? targetDelta = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,effectiveAt: null == effectiveAt ? _self.effectiveAt : effectiveAt // ignore: cast_nullable_to_non_nullable
as DateTime,profitTargetPct: null == profitTargetPct ? _self.profitTargetPct : profitTargetPct // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [RuleProfileVersionData].
extension RuleProfileVersionDataPatterns on RuleProfileVersionData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleProfileVersionData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleProfileVersionData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleProfileVersionData value)  $default,){
final _that = this;
switch (_that) {
case _RuleProfileVersionData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleProfileVersionData value)?  $default,){
final _that = this;
switch (_that) {
case _RuleProfileVersionData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String profileId,  int version,  DateTime effectiveAt,  double profitTargetPct,  double assignThreshold,  double baseRollBand,  double midIvRollBand,  double highIvRollBand,  double midIvCutoff,  double highIvCutoff,  int tailDteDays, @DecimalJsonConverter()  Decimal tailExtrinsicThreshold,  double minIvRank,  double minAnnualisedYield,  int targetDteMin,  int targetDteMax,  double targetDelta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleProfileVersionData() when $default != null:
return $default(_that.id,_that.profileId,_that.version,_that.effectiveAt,_that.profitTargetPct,_that.assignThreshold,_that.baseRollBand,_that.midIvRollBand,_that.highIvRollBand,_that.midIvCutoff,_that.highIvCutoff,_that.tailDteDays,_that.tailExtrinsicThreshold,_that.minIvRank,_that.minAnnualisedYield,_that.targetDteMin,_that.targetDteMax,_that.targetDelta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String profileId,  int version,  DateTime effectiveAt,  double profitTargetPct,  double assignThreshold,  double baseRollBand,  double midIvRollBand,  double highIvRollBand,  double midIvCutoff,  double highIvCutoff,  int tailDteDays, @DecimalJsonConverter()  Decimal tailExtrinsicThreshold,  double minIvRank,  double minAnnualisedYield,  int targetDteMin,  int targetDteMax,  double targetDelta)  $default,) {final _that = this;
switch (_that) {
case _RuleProfileVersionData():
return $default(_that.id,_that.profileId,_that.version,_that.effectiveAt,_that.profitTargetPct,_that.assignThreshold,_that.baseRollBand,_that.midIvRollBand,_that.highIvRollBand,_that.midIvCutoff,_that.highIvCutoff,_that.tailDteDays,_that.tailExtrinsicThreshold,_that.minIvRank,_that.minAnnualisedYield,_that.targetDteMin,_that.targetDteMax,_that.targetDelta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String profileId,  int version,  DateTime effectiveAt,  double profitTargetPct,  double assignThreshold,  double baseRollBand,  double midIvRollBand,  double highIvRollBand,  double midIvCutoff,  double highIvCutoff,  int tailDteDays, @DecimalJsonConverter()  Decimal tailExtrinsicThreshold,  double minIvRank,  double minAnnualisedYield,  int targetDteMin,  int targetDteMax,  double targetDelta)?  $default,) {final _that = this;
switch (_that) {
case _RuleProfileVersionData() when $default != null:
return $default(_that.id,_that.profileId,_that.version,_that.effectiveAt,_that.profitTargetPct,_that.assignThreshold,_that.baseRollBand,_that.midIvRollBand,_that.highIvRollBand,_that.midIvCutoff,_that.highIvCutoff,_that.tailDteDays,_that.tailExtrinsicThreshold,_that.minIvRank,_that.minAnnualisedYield,_that.targetDteMin,_that.targetDteMax,_that.targetDelta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RuleProfileVersionData implements RuleProfileVersionData {
  const _RuleProfileVersionData({required this.id, required this.profileId, required this.version, required this.effectiveAt, required this.profitTargetPct, required this.assignThreshold, required this.baseRollBand, required this.midIvRollBand, required this.highIvRollBand, required this.midIvCutoff, required this.highIvCutoff, required this.tailDteDays, @DecimalJsonConverter() required this.tailExtrinsicThreshold, required this.minIvRank, required this.minAnnualisedYield, required this.targetDteMin, required this.targetDteMax, required this.targetDelta});
  factory _RuleProfileVersionData.fromJson(Map<String, dynamic> json) => _$RuleProfileVersionDataFromJson(json);

@override final  String id;
@override final  String profileId;
@override final  int version;
@override final  DateTime effectiveAt;
@override final  double profitTargetPct;
@override final  double assignThreshold;
@override final  double baseRollBand;
@override final  double midIvRollBand;
@override final  double highIvRollBand;
@override final  double midIvCutoff;
@override final  double highIvCutoff;
@override final  int tailDteDays;
@override@DecimalJsonConverter() final  Decimal tailExtrinsicThreshold;
@override final  double minIvRank;
@override final  double minAnnualisedYield;
@override final  int targetDteMin;
@override final  int targetDteMax;
@override final  double targetDelta;

/// Create a copy of RuleProfileVersionData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleProfileVersionDataCopyWith<_RuleProfileVersionData> get copyWith => __$RuleProfileVersionDataCopyWithImpl<_RuleProfileVersionData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleProfileVersionDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleProfileVersionData&&(identical(other.id, id) || other.id == id)&&(identical(other.profileId, profileId) || other.profileId == profileId)&&(identical(other.version, version) || other.version == version)&&(identical(other.effectiveAt, effectiveAt) || other.effectiveAt == effectiveAt)&&(identical(other.profitTargetPct, profitTargetPct) || other.profitTargetPct == profitTargetPct)&&(identical(other.assignThreshold, assignThreshold) || other.assignThreshold == assignThreshold)&&(identical(other.baseRollBand, baseRollBand) || other.baseRollBand == baseRollBand)&&(identical(other.midIvRollBand, midIvRollBand) || other.midIvRollBand == midIvRollBand)&&(identical(other.highIvRollBand, highIvRollBand) || other.highIvRollBand == highIvRollBand)&&(identical(other.midIvCutoff, midIvCutoff) || other.midIvCutoff == midIvCutoff)&&(identical(other.highIvCutoff, highIvCutoff) || other.highIvCutoff == highIvCutoff)&&(identical(other.tailDteDays, tailDteDays) || other.tailDteDays == tailDteDays)&&(identical(other.tailExtrinsicThreshold, tailExtrinsicThreshold) || other.tailExtrinsicThreshold == tailExtrinsicThreshold)&&(identical(other.minIvRank, minIvRank) || other.minIvRank == minIvRank)&&(identical(other.minAnnualisedYield, minAnnualisedYield) || other.minAnnualisedYield == minAnnualisedYield)&&(identical(other.targetDteMin, targetDteMin) || other.targetDteMin == targetDteMin)&&(identical(other.targetDteMax, targetDteMax) || other.targetDteMax == targetDteMax)&&(identical(other.targetDelta, targetDelta) || other.targetDelta == targetDelta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,profileId,version,effectiveAt,profitTargetPct,assignThreshold,baseRollBand,midIvRollBand,highIvRollBand,midIvCutoff,highIvCutoff,tailDteDays,tailExtrinsicThreshold,minIvRank,minAnnualisedYield,targetDteMin,targetDteMax,targetDelta);

@override
String toString() {
  return 'RuleProfileVersionData(id: $id, profileId: $profileId, version: $version, effectiveAt: $effectiveAt, profitTargetPct: $profitTargetPct, assignThreshold: $assignThreshold, baseRollBand: $baseRollBand, midIvRollBand: $midIvRollBand, highIvRollBand: $highIvRollBand, midIvCutoff: $midIvCutoff, highIvCutoff: $highIvCutoff, tailDteDays: $tailDteDays, tailExtrinsicThreshold: $tailExtrinsicThreshold, minIvRank: $minIvRank, minAnnualisedYield: $minAnnualisedYield, targetDteMin: $targetDteMin, targetDteMax: $targetDteMax, targetDelta: $targetDelta)';
}


}

/// @nodoc
abstract mixin class _$RuleProfileVersionDataCopyWith<$Res> implements $RuleProfileVersionDataCopyWith<$Res> {
  factory _$RuleProfileVersionDataCopyWith(_RuleProfileVersionData value, $Res Function(_RuleProfileVersionData) _then) = __$RuleProfileVersionDataCopyWithImpl;
@override @useResult
$Res call({
 String id, String profileId, int version, DateTime effectiveAt, double profitTargetPct, double assignThreshold, double baseRollBand, double midIvRollBand, double highIvRollBand, double midIvCutoff, double highIvCutoff, int tailDteDays,@DecimalJsonConverter() Decimal tailExtrinsicThreshold, double minIvRank, double minAnnualisedYield, int targetDteMin, int targetDteMax, double targetDelta
});




}
/// @nodoc
class __$RuleProfileVersionDataCopyWithImpl<$Res>
    implements _$RuleProfileVersionDataCopyWith<$Res> {
  __$RuleProfileVersionDataCopyWithImpl(this._self, this._then);

  final _RuleProfileVersionData _self;
  final $Res Function(_RuleProfileVersionData) _then;

/// Create a copy of RuleProfileVersionData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? profileId = null,Object? version = null,Object? effectiveAt = null,Object? profitTargetPct = null,Object? assignThreshold = null,Object? baseRollBand = null,Object? midIvRollBand = null,Object? highIvRollBand = null,Object? midIvCutoff = null,Object? highIvCutoff = null,Object? tailDteDays = null,Object? tailExtrinsicThreshold = null,Object? minIvRank = null,Object? minAnnualisedYield = null,Object? targetDteMin = null,Object? targetDteMax = null,Object? targetDelta = null,}) {
  return _then(_RuleProfileVersionData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,profileId: null == profileId ? _self.profileId : profileId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,effectiveAt: null == effectiveAt ? _self.effectiveAt : effectiveAt // ignore: cast_nullable_to_non_nullable
as DateTime,profitTargetPct: null == profitTargetPct ? _self.profitTargetPct : profitTargetPct // ignore: cast_nullable_to_non_nullable
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

// dart format on
