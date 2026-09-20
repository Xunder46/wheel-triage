// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Snapshot {

 String get id; String get legId; DateTime get takenAt;@DecimalJsonConverter() Decimal get optionMark;@DecimalJsonConverter() Decimal get underlyingPrice; double get deltaAsEntered; DeltaConvention get deltaConvention; double? get gamma; double? get theta; double? get vega; double? get iv; int? get openInterest; int? get volume;
/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotCopyWith<Snapshot> get copyWith => _$SnapshotCopyWithImpl<Snapshot>(this as Snapshot, _$identity);

  /// Serializes this Snapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Snapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.legId, legId) || other.legId == legId)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt)&&(identical(other.optionMark, optionMark) || other.optionMark == optionMark)&&(identical(other.underlyingPrice, underlyingPrice) || other.underlyingPrice == underlyingPrice)&&(identical(other.deltaAsEntered, deltaAsEntered) || other.deltaAsEntered == deltaAsEntered)&&(identical(other.deltaConvention, deltaConvention) || other.deltaConvention == deltaConvention)&&(identical(other.gamma, gamma) || other.gamma == gamma)&&(identical(other.theta, theta) || other.theta == theta)&&(identical(other.vega, vega) || other.vega == vega)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.openInterest, openInterest) || other.openInterest == openInterest)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,legId,takenAt,optionMark,underlyingPrice,deltaAsEntered,deltaConvention,gamma,theta,vega,iv,openInterest,volume);

@override
String toString() {
  return 'Snapshot(id: $id, legId: $legId, takenAt: $takenAt, optionMark: $optionMark, underlyingPrice: $underlyingPrice, deltaAsEntered: $deltaAsEntered, deltaConvention: $deltaConvention, gamma: $gamma, theta: $theta, vega: $vega, iv: $iv, openInterest: $openInterest, volume: $volume)';
}


}

/// @nodoc
abstract mixin class $SnapshotCopyWith<$Res>  {
  factory $SnapshotCopyWith(Snapshot value, $Res Function(Snapshot) _then) = _$SnapshotCopyWithImpl;
@useResult
$Res call({
 String id, String legId, DateTime takenAt,@DecimalJsonConverter() Decimal optionMark,@DecimalJsonConverter() Decimal underlyingPrice, double deltaAsEntered, DeltaConvention deltaConvention, double? gamma, double? theta, double? vega, double? iv, int? openInterest, int? volume
});




}
/// @nodoc
class _$SnapshotCopyWithImpl<$Res>
    implements $SnapshotCopyWith<$Res> {
  _$SnapshotCopyWithImpl(this._self, this._then);

  final Snapshot _self;
  final $Res Function(Snapshot) _then;

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? legId = null,Object? takenAt = null,Object? optionMark = null,Object? underlyingPrice = null,Object? deltaAsEntered = null,Object? deltaConvention = null,Object? gamma = freezed,Object? theta = freezed,Object? vega = freezed,Object? iv = freezed,Object? openInterest = freezed,Object? volume = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,legId: null == legId ? _self.legId : legId // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [Snapshot].
extension SnapshotPatterns on Snapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Snapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Snapshot value)  $default,){
final _that = this;
switch (_that) {
case _Snapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Snapshot value)?  $default,){
final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String legId,  DateTime takenAt, @DecimalJsonConverter()  Decimal optionMark, @DecimalJsonConverter()  Decimal underlyingPrice,  double deltaAsEntered,  DeltaConvention deltaConvention,  double? gamma,  double? theta,  double? vega,  double? iv,  int? openInterest,  int? volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
return $default(_that.id,_that.legId,_that.takenAt,_that.optionMark,_that.underlyingPrice,_that.deltaAsEntered,_that.deltaConvention,_that.gamma,_that.theta,_that.vega,_that.iv,_that.openInterest,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String legId,  DateTime takenAt, @DecimalJsonConverter()  Decimal optionMark, @DecimalJsonConverter()  Decimal underlyingPrice,  double deltaAsEntered,  DeltaConvention deltaConvention,  double? gamma,  double? theta,  double? vega,  double? iv,  int? openInterest,  int? volume)  $default,) {final _that = this;
switch (_that) {
case _Snapshot():
return $default(_that.id,_that.legId,_that.takenAt,_that.optionMark,_that.underlyingPrice,_that.deltaAsEntered,_that.deltaConvention,_that.gamma,_that.theta,_that.vega,_that.iv,_that.openInterest,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String legId,  DateTime takenAt, @DecimalJsonConverter()  Decimal optionMark, @DecimalJsonConverter()  Decimal underlyingPrice,  double deltaAsEntered,  DeltaConvention deltaConvention,  double? gamma,  double? theta,  double? vega,  double? iv,  int? openInterest,  int? volume)?  $default,) {final _that = this;
switch (_that) {
case _Snapshot() when $default != null:
return $default(_that.id,_that.legId,_that.takenAt,_that.optionMark,_that.underlyingPrice,_that.deltaAsEntered,_that.deltaConvention,_that.gamma,_that.theta,_that.vega,_that.iv,_that.openInterest,_that.volume);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Snapshot implements Snapshot {
  const _Snapshot({required this.id, required this.legId, required this.takenAt, @DecimalJsonConverter() required this.optionMark, @DecimalJsonConverter() required this.underlyingPrice, required this.deltaAsEntered, required this.deltaConvention, this.gamma, this.theta, this.vega, this.iv, this.openInterest, this.volume});
  factory _Snapshot.fromJson(Map<String, dynamic> json) => _$SnapshotFromJson(json);

@override final  String id;
@override final  String legId;
@override final  DateTime takenAt;
@override@DecimalJsonConverter() final  Decimal optionMark;
@override@DecimalJsonConverter() final  Decimal underlyingPrice;
@override final  double deltaAsEntered;
@override final  DeltaConvention deltaConvention;
@override final  double? gamma;
@override final  double? theta;
@override final  double? vega;
@override final  double? iv;
@override final  int? openInterest;
@override final  int? volume;

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotCopyWith<_Snapshot> get copyWith => __$SnapshotCopyWithImpl<_Snapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Snapshot&&(identical(other.id, id) || other.id == id)&&(identical(other.legId, legId) || other.legId == legId)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt)&&(identical(other.optionMark, optionMark) || other.optionMark == optionMark)&&(identical(other.underlyingPrice, underlyingPrice) || other.underlyingPrice == underlyingPrice)&&(identical(other.deltaAsEntered, deltaAsEntered) || other.deltaAsEntered == deltaAsEntered)&&(identical(other.deltaConvention, deltaConvention) || other.deltaConvention == deltaConvention)&&(identical(other.gamma, gamma) || other.gamma == gamma)&&(identical(other.theta, theta) || other.theta == theta)&&(identical(other.vega, vega) || other.vega == vega)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.openInterest, openInterest) || other.openInterest == openInterest)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,legId,takenAt,optionMark,underlyingPrice,deltaAsEntered,deltaConvention,gamma,theta,vega,iv,openInterest,volume);

@override
String toString() {
  return 'Snapshot(id: $id, legId: $legId, takenAt: $takenAt, optionMark: $optionMark, underlyingPrice: $underlyingPrice, deltaAsEntered: $deltaAsEntered, deltaConvention: $deltaConvention, gamma: $gamma, theta: $theta, vega: $vega, iv: $iv, openInterest: $openInterest, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$SnapshotCopyWith<$Res> implements $SnapshotCopyWith<$Res> {
  factory _$SnapshotCopyWith(_Snapshot value, $Res Function(_Snapshot) _then) = __$SnapshotCopyWithImpl;
@override @useResult
$Res call({
 String id, String legId, DateTime takenAt,@DecimalJsonConverter() Decimal optionMark,@DecimalJsonConverter() Decimal underlyingPrice, double deltaAsEntered, DeltaConvention deltaConvention, double? gamma, double? theta, double? vega, double? iv, int? openInterest, int? volume
});




}
/// @nodoc
class __$SnapshotCopyWithImpl<$Res>
    implements _$SnapshotCopyWith<$Res> {
  __$SnapshotCopyWithImpl(this._self, this._then);

  final _Snapshot _self;
  final $Res Function(_Snapshot) _then;

/// Create a copy of Snapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? legId = null,Object? takenAt = null,Object? optionMark = null,Object? underlyingPrice = null,Object? deltaAsEntered = null,Object? deltaConvention = null,Object? gamma = freezed,Object? theta = freezed,Object? vega = freezed,Object? iv = freezed,Object? openInterest = freezed,Object? volume = freezed,}) {
  return _then(_Snapshot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,legId: null == legId ? _self.legId : legId // ignore: cast_nullable_to_non_nullable
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

// dart format on
