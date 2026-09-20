// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'share_lot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ShareLot {

 String get id; String get cycleId; DateTime get assignedAt;@DecimalJsonConverter() Decimal get assignmentStrike; int get contracts;
/// Create a copy of ShareLot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShareLotCopyWith<ShareLot> get copyWith => _$ShareLotCopyWithImpl<ShareLot>(this as ShareLot, _$identity);

  /// Serializes this ShareLot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShareLot&&(identical(other.id, id) || other.id == id)&&(identical(other.cycleId, cycleId) || other.cycleId == cycleId)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.assignmentStrike, assignmentStrike) || other.assignmentStrike == assignmentStrike)&&(identical(other.contracts, contracts) || other.contracts == contracts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cycleId,assignedAt,assignmentStrike,contracts);

@override
String toString() {
  return 'ShareLot(id: $id, cycleId: $cycleId, assignedAt: $assignedAt, assignmentStrike: $assignmentStrike, contracts: $contracts)';
}


}

/// @nodoc
abstract mixin class $ShareLotCopyWith<$Res>  {
  factory $ShareLotCopyWith(ShareLot value, $Res Function(ShareLot) _then) = _$ShareLotCopyWithImpl;
@useResult
$Res call({
 String id, String cycleId, DateTime assignedAt,@DecimalJsonConverter() Decimal assignmentStrike, int contracts
});




}
/// @nodoc
class _$ShareLotCopyWithImpl<$Res>
    implements $ShareLotCopyWith<$Res> {
  _$ShareLotCopyWithImpl(this._self, this._then);

  final ShareLot _self;
  final $Res Function(ShareLot) _then;

/// Create a copy of ShareLot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? cycleId = null,Object? assignedAt = null,Object? assignmentStrike = null,Object? contracts = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,cycleId: null == cycleId ? _self.cycleId : cycleId // ignore: cast_nullable_to_non_nullable
as String,assignedAt: null == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assignmentStrike: null == assignmentStrike ? _self.assignmentStrike : assignmentStrike // ignore: cast_nullable_to_non_nullable
as Decimal,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ShareLot].
extension ShareLotPatterns on ShareLot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShareLot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShareLot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShareLot value)  $default,){
final _that = this;
switch (_that) {
case _ShareLot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShareLot value)?  $default,){
final _that = this;
switch (_that) {
case _ShareLot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String cycleId,  DateTime assignedAt, @DecimalJsonConverter()  Decimal assignmentStrike,  int contracts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShareLot() when $default != null:
return $default(_that.id,_that.cycleId,_that.assignedAt,_that.assignmentStrike,_that.contracts);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String cycleId,  DateTime assignedAt, @DecimalJsonConverter()  Decimal assignmentStrike,  int contracts)  $default,) {final _that = this;
switch (_that) {
case _ShareLot():
return $default(_that.id,_that.cycleId,_that.assignedAt,_that.assignmentStrike,_that.contracts);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String cycleId,  DateTime assignedAt, @DecimalJsonConverter()  Decimal assignmentStrike,  int contracts)?  $default,) {final _that = this;
switch (_that) {
case _ShareLot() when $default != null:
return $default(_that.id,_that.cycleId,_that.assignedAt,_that.assignmentStrike,_that.contracts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShareLot implements ShareLot {
  const _ShareLot({required this.id, required this.cycleId, required this.assignedAt, @DecimalJsonConverter() required this.assignmentStrike, required this.contracts});
  factory _ShareLot.fromJson(Map<String, dynamic> json) => _$ShareLotFromJson(json);

@override final  String id;
@override final  String cycleId;
@override final  DateTime assignedAt;
@override@DecimalJsonConverter() final  Decimal assignmentStrike;
@override final  int contracts;

/// Create a copy of ShareLot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShareLotCopyWith<_ShareLot> get copyWith => __$ShareLotCopyWithImpl<_ShareLot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShareLotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShareLot&&(identical(other.id, id) || other.id == id)&&(identical(other.cycleId, cycleId) || other.cycleId == cycleId)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.assignmentStrike, assignmentStrike) || other.assignmentStrike == assignmentStrike)&&(identical(other.contracts, contracts) || other.contracts == contracts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,cycleId,assignedAt,assignmentStrike,contracts);

@override
String toString() {
  return 'ShareLot(id: $id, cycleId: $cycleId, assignedAt: $assignedAt, assignmentStrike: $assignmentStrike, contracts: $contracts)';
}


}

/// @nodoc
abstract mixin class _$ShareLotCopyWith<$Res> implements $ShareLotCopyWith<$Res> {
  factory _$ShareLotCopyWith(_ShareLot value, $Res Function(_ShareLot) _then) = __$ShareLotCopyWithImpl;
@override @useResult
$Res call({
 String id, String cycleId, DateTime assignedAt,@DecimalJsonConverter() Decimal assignmentStrike, int contracts
});




}
/// @nodoc
class __$ShareLotCopyWithImpl<$Res>
    implements _$ShareLotCopyWith<$Res> {
  __$ShareLotCopyWithImpl(this._self, this._then);

  final _ShareLot _self;
  final $Res Function(_ShareLot) _then;

/// Create a copy of ShareLot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? cycleId = null,Object? assignedAt = null,Object? assignmentStrike = null,Object? contracts = null,}) {
  return _then(_ShareLot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,cycleId: null == cycleId ? _self.cycleId : cycleId // ignore: cast_nullable_to_non_nullable
as String,assignedAt: null == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assignmentStrike: null == assignmentStrike ? _self.assignmentStrike : assignmentStrike // ignore: cast_nullable_to_non_nullable
as Decimal,contracts: null == contracts ? _self.contracts : contracts // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
