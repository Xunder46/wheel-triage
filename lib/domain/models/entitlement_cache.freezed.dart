// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entitlement_cache.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EntitlementCacheData {

/// Whether the store reported an active entitlement on the last
/// successful read. `false` covers both "the store said no" and "never
/// checked" — [checkedAt] is what tells those two apart (D-26).
 bool get isActive;/// Which plan the store reported. `none` on the free tier.
 ProPlanKind get planKind;/// When the entitlement expires, or `null` for lifetime and for
/// "never checked".
 DateTime? get expiresAt;/// Whether the store says the subscription will renew. `false` for
/// lifetime and for a cancelled-but-not-yet-expired subscription, which
/// stays active until the paid period ends (D-26).
 bool get willRenew;/// Whether the store reports a billing problem. Display only — a
/// subscription in billing retry is still active (D-26).
 bool get billingIssue;/// The store's `originalPurchaseDate`, for the Settings plan row.
 DateTime? get purchasedAt;/// When this row was last written from a successful store read; `null`
/// means no read has ever succeeded, which is what makes the state
/// `unknown` rather than `inactive` (D-26).
 DateTime? get checkedAt;
/// Create a copy of EntitlementCacheData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntitlementCacheDataCopyWith<EntitlementCacheData> get copyWith => _$EntitlementCacheDataCopyWithImpl<EntitlementCacheData>(this as EntitlementCacheData, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntitlementCacheData&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.planKind, planKind) || other.planKind == planKind)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.willRenew, willRenew) || other.willRenew == willRenew)&&(identical(other.billingIssue, billingIssue) || other.billingIssue == billingIssue)&&(identical(other.purchasedAt, purchasedAt) || other.purchasedAt == purchasedAt)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt));
}


@override
int get hashCode => Object.hash(runtimeType,isActive,planKind,expiresAt,willRenew,billingIssue,purchasedAt,checkedAt);

@override
String toString() {
  return 'EntitlementCacheData(isActive: $isActive, planKind: $planKind, expiresAt: $expiresAt, willRenew: $willRenew, billingIssue: $billingIssue, purchasedAt: $purchasedAt, checkedAt: $checkedAt)';
}


}

/// @nodoc
abstract mixin class $EntitlementCacheDataCopyWith<$Res>  {
  factory $EntitlementCacheDataCopyWith(EntitlementCacheData value, $Res Function(EntitlementCacheData) _then) = _$EntitlementCacheDataCopyWithImpl;
@useResult
$Res call({
 bool isActive, ProPlanKind planKind, DateTime? expiresAt, bool willRenew, bool billingIssue, DateTime? purchasedAt, DateTime? checkedAt
});




}
/// @nodoc
class _$EntitlementCacheDataCopyWithImpl<$Res>
    implements $EntitlementCacheDataCopyWith<$Res> {
  _$EntitlementCacheDataCopyWithImpl(this._self, this._then);

  final EntitlementCacheData _self;
  final $Res Function(EntitlementCacheData) _then;

/// Create a copy of EntitlementCacheData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isActive = null,Object? planKind = null,Object? expiresAt = freezed,Object? willRenew = null,Object? billingIssue = null,Object? purchasedAt = freezed,Object? checkedAt = freezed,}) {
  return _then(_self.copyWith(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,planKind: null == planKind ? _self.planKind : planKind // ignore: cast_nullable_to_non_nullable
as ProPlanKind,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,willRenew: null == willRenew ? _self.willRenew : willRenew // ignore: cast_nullable_to_non_nullable
as bool,billingIssue: null == billingIssue ? _self.billingIssue : billingIssue // ignore: cast_nullable_to_non_nullable
as bool,purchasedAt: freezed == purchasedAt ? _self.purchasedAt : purchasedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,checkedAt: freezed == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [EntitlementCacheData].
extension EntitlementCacheDataPatterns on EntitlementCacheData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntitlementCacheData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntitlementCacheData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntitlementCacheData value)  $default,){
final _that = this;
switch (_that) {
case _EntitlementCacheData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntitlementCacheData value)?  $default,){
final _that = this;
switch (_that) {
case _EntitlementCacheData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isActive,  ProPlanKind planKind,  DateTime? expiresAt,  bool willRenew,  bool billingIssue,  DateTime? purchasedAt,  DateTime? checkedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntitlementCacheData() when $default != null:
return $default(_that.isActive,_that.planKind,_that.expiresAt,_that.willRenew,_that.billingIssue,_that.purchasedAt,_that.checkedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isActive,  ProPlanKind planKind,  DateTime? expiresAt,  bool willRenew,  bool billingIssue,  DateTime? purchasedAt,  DateTime? checkedAt)  $default,) {final _that = this;
switch (_that) {
case _EntitlementCacheData():
return $default(_that.isActive,_that.planKind,_that.expiresAt,_that.willRenew,_that.billingIssue,_that.purchasedAt,_that.checkedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isActive,  ProPlanKind planKind,  DateTime? expiresAt,  bool willRenew,  bool billingIssue,  DateTime? purchasedAt,  DateTime? checkedAt)?  $default,) {final _that = this;
switch (_that) {
case _EntitlementCacheData() when $default != null:
return $default(_that.isActive,_that.planKind,_that.expiresAt,_that.willRenew,_that.billingIssue,_that.purchasedAt,_that.checkedAt);case _:
  return null;

}
}

}

/// @nodoc


class _EntitlementCacheData implements EntitlementCacheData {
  const _EntitlementCacheData({this.isActive = false, this.planKind = ProPlanKind.none, this.expiresAt, this.willRenew = false, this.billingIssue = false, this.purchasedAt, this.checkedAt});
  

/// Whether the store reported an active entitlement on the last
/// successful read. `false` covers both "the store said no" and "never
/// checked" — [checkedAt] is what tells those two apart (D-26).
@override@JsonKey() final  bool isActive;
/// Which plan the store reported. `none` on the free tier.
@override@JsonKey() final  ProPlanKind planKind;
/// When the entitlement expires, or `null` for lifetime and for
/// "never checked".
@override final  DateTime? expiresAt;
/// Whether the store says the subscription will renew. `false` for
/// lifetime and for a cancelled-but-not-yet-expired subscription, which
/// stays active until the paid period ends (D-26).
@override@JsonKey() final  bool willRenew;
/// Whether the store reports a billing problem. Display only — a
/// subscription in billing retry is still active (D-26).
@override@JsonKey() final  bool billingIssue;
/// The store's `originalPurchaseDate`, for the Settings plan row.
@override final  DateTime? purchasedAt;
/// When this row was last written from a successful store read; `null`
/// means no read has ever succeeded, which is what makes the state
/// `unknown` rather than `inactive` (D-26).
@override final  DateTime? checkedAt;

/// Create a copy of EntitlementCacheData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntitlementCacheDataCopyWith<_EntitlementCacheData> get copyWith => __$EntitlementCacheDataCopyWithImpl<_EntitlementCacheData>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntitlementCacheData&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.planKind, planKind) || other.planKind == planKind)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.willRenew, willRenew) || other.willRenew == willRenew)&&(identical(other.billingIssue, billingIssue) || other.billingIssue == billingIssue)&&(identical(other.purchasedAt, purchasedAt) || other.purchasedAt == purchasedAt)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt));
}


@override
int get hashCode => Object.hash(runtimeType,isActive,planKind,expiresAt,willRenew,billingIssue,purchasedAt,checkedAt);

@override
String toString() {
  return 'EntitlementCacheData(isActive: $isActive, planKind: $planKind, expiresAt: $expiresAt, willRenew: $willRenew, billingIssue: $billingIssue, purchasedAt: $purchasedAt, checkedAt: $checkedAt)';
}


}

/// @nodoc
abstract mixin class _$EntitlementCacheDataCopyWith<$Res> implements $EntitlementCacheDataCopyWith<$Res> {
  factory _$EntitlementCacheDataCopyWith(_EntitlementCacheData value, $Res Function(_EntitlementCacheData) _then) = __$EntitlementCacheDataCopyWithImpl;
@override @useResult
$Res call({
 bool isActive, ProPlanKind planKind, DateTime? expiresAt, bool willRenew, bool billingIssue, DateTime? purchasedAt, DateTime? checkedAt
});




}
/// @nodoc
class __$EntitlementCacheDataCopyWithImpl<$Res>
    implements _$EntitlementCacheDataCopyWith<$Res> {
  __$EntitlementCacheDataCopyWithImpl(this._self, this._then);

  final _EntitlementCacheData _self;
  final $Res Function(_EntitlementCacheData) _then;

/// Create a copy of EntitlementCacheData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isActive = null,Object? planKind = null,Object? expiresAt = freezed,Object? willRenew = null,Object? billingIssue = null,Object? purchasedAt = freezed,Object? checkedAt = freezed,}) {
  return _then(_EntitlementCacheData(
isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,planKind: null == planKind ? _self.planKind : planKind // ignore: cast_nullable_to_non_nullable
as ProPlanKind,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,willRenew: null == willRenew ? _self.willRenew : willRenew // ignore: cast_nullable_to_non_nullable
as bool,billingIssue: null == billingIssue ? _self.billingIssue : billingIssue // ignore: cast_nullable_to_non_nullable
as bool,purchasedAt: freezed == purchasedAt ? _self.purchasedAt : purchasedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,checkedAt: freezed == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
