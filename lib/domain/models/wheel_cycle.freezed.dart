// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wheel_cycle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WheelCycle {

 String get id; String get underlyingId; DateTime get startedAt; DateTime? get endedAt; WheelCycleStatus get status; WheelCycleOutcome? get outcome;
/// Create a copy of WheelCycle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WheelCycleCopyWith<WheelCycle> get copyWith => _$WheelCycleCopyWithImpl<WheelCycle>(this as WheelCycle, _$identity);

  /// Serializes this WheelCycle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WheelCycle&&(identical(other.id, id) || other.id == id)&&(identical(other.underlyingId, underlyingId) || other.underlyingId == underlyingId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,underlyingId,startedAt,endedAt,status,outcome);

@override
String toString() {
  return 'WheelCycle(id: $id, underlyingId: $underlyingId, startedAt: $startedAt, endedAt: $endedAt, status: $status, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class $WheelCycleCopyWith<$Res>  {
  factory $WheelCycleCopyWith(WheelCycle value, $Res Function(WheelCycle) _then) = _$WheelCycleCopyWithImpl;
@useResult
$Res call({
 String id, String underlyingId, DateTime startedAt, DateTime? endedAt, WheelCycleStatus status, WheelCycleOutcome? outcome
});




}
/// @nodoc
class _$WheelCycleCopyWithImpl<$Res>
    implements $WheelCycleCopyWith<$Res> {
  _$WheelCycleCopyWithImpl(this._self, this._then);

  final WheelCycle _self;
  final $Res Function(WheelCycle) _then;

/// Create a copy of WheelCycle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? underlyingId = null,Object? startedAt = null,Object? endedAt = freezed,Object? status = null,Object? outcome = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,underlyingId: null == underlyingId ? _self.underlyingId : underlyingId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WheelCycleStatus,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as WheelCycleOutcome?,
  ));
}

}


/// Adds pattern-matching-related methods to [WheelCycle].
extension WheelCyclePatterns on WheelCycle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WheelCycle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WheelCycle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WheelCycle value)  $default,){
final _that = this;
switch (_that) {
case _WheelCycle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WheelCycle value)?  $default,){
final _that = this;
switch (_that) {
case _WheelCycle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String underlyingId,  DateTime startedAt,  DateTime? endedAt,  WheelCycleStatus status,  WheelCycleOutcome? outcome)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WheelCycle() when $default != null:
return $default(_that.id,_that.underlyingId,_that.startedAt,_that.endedAt,_that.status,_that.outcome);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String underlyingId,  DateTime startedAt,  DateTime? endedAt,  WheelCycleStatus status,  WheelCycleOutcome? outcome)  $default,) {final _that = this;
switch (_that) {
case _WheelCycle():
return $default(_that.id,_that.underlyingId,_that.startedAt,_that.endedAt,_that.status,_that.outcome);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String underlyingId,  DateTime startedAt,  DateTime? endedAt,  WheelCycleStatus status,  WheelCycleOutcome? outcome)?  $default,) {final _that = this;
switch (_that) {
case _WheelCycle() when $default != null:
return $default(_that.id,_that.underlyingId,_that.startedAt,_that.endedAt,_that.status,_that.outcome);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WheelCycle implements WheelCycle {
  const _WheelCycle({required this.id, required this.underlyingId, required this.startedAt, this.endedAt, required this.status, this.outcome});
  factory _WheelCycle.fromJson(Map<String, dynamic> json) => _$WheelCycleFromJson(json);

@override final  String id;
@override final  String underlyingId;
@override final  DateTime startedAt;
@override final  DateTime? endedAt;
@override final  WheelCycleStatus status;
@override final  WheelCycleOutcome? outcome;

/// Create a copy of WheelCycle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WheelCycleCopyWith<_WheelCycle> get copyWith => __$WheelCycleCopyWithImpl<_WheelCycle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WheelCycleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WheelCycle&&(identical(other.id, id) || other.id == id)&&(identical(other.underlyingId, underlyingId) || other.underlyingId == underlyingId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.outcome, outcome) || other.outcome == outcome));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,underlyingId,startedAt,endedAt,status,outcome);

@override
String toString() {
  return 'WheelCycle(id: $id, underlyingId: $underlyingId, startedAt: $startedAt, endedAt: $endedAt, status: $status, outcome: $outcome)';
}


}

/// @nodoc
abstract mixin class _$WheelCycleCopyWith<$Res> implements $WheelCycleCopyWith<$Res> {
  factory _$WheelCycleCopyWith(_WheelCycle value, $Res Function(_WheelCycle) _then) = __$WheelCycleCopyWithImpl;
@override @useResult
$Res call({
 String id, String underlyingId, DateTime startedAt, DateTime? endedAt, WheelCycleStatus status, WheelCycleOutcome? outcome
});




}
/// @nodoc
class __$WheelCycleCopyWithImpl<$Res>
    implements _$WheelCycleCopyWith<$Res> {
  __$WheelCycleCopyWithImpl(this._self, this._then);

  final _WheelCycle _self;
  final $Res Function(_WheelCycle) _then;

/// Create a copy of WheelCycle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? underlyingId = null,Object? startedAt = null,Object? endedAt = freezed,Object? status = null,Object? outcome = freezed,}) {
  return _then(_WheelCycle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,underlyingId: null == underlyingId ? _self.underlyingId : underlyingId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as WheelCycleStatus,outcome: freezed == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as WheelCycleOutcome?,
  ));
}


}

// dart format on
