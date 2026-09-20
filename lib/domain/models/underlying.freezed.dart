// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'underlying.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Underlying {

 String get id; String get ticker; String? get displayName; String? get notes;
/// Create a copy of Underlying
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnderlyingCopyWith<Underlying> get copyWith => _$UnderlyingCopyWithImpl<Underlying>(this as Underlying, _$identity);

  /// Serializes this Underlying to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Underlying&&(identical(other.id, id) || other.id == id)&&(identical(other.ticker, ticker) || other.ticker == ticker)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticker,displayName,notes);

@override
String toString() {
  return 'Underlying(id: $id, ticker: $ticker, displayName: $displayName, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $UnderlyingCopyWith<$Res>  {
  factory $UnderlyingCopyWith(Underlying value, $Res Function(Underlying) _then) = _$UnderlyingCopyWithImpl;
@useResult
$Res call({
 String id, String ticker, String? displayName, String? notes
});




}
/// @nodoc
class _$UnderlyingCopyWithImpl<$Res>
    implements $UnderlyingCopyWith<$Res> {
  _$UnderlyingCopyWithImpl(this._self, this._then);

  final Underlying _self;
  final $Res Function(Underlying) _then;

/// Create a copy of Underlying
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ticker = null,Object? displayName = freezed,Object? notes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticker: null == ticker ? _self.ticker : ticker // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Underlying].
extension UnderlyingPatterns on Underlying {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Underlying value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Underlying() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Underlying value)  $default,){
final _that = this;
switch (_that) {
case _Underlying():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Underlying value)?  $default,){
final _that = this;
switch (_that) {
case _Underlying() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ticker,  String? displayName,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Underlying() when $default != null:
return $default(_that.id,_that.ticker,_that.displayName,_that.notes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ticker,  String? displayName,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _Underlying():
return $default(_that.id,_that.ticker,_that.displayName,_that.notes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ticker,  String? displayName,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _Underlying() when $default != null:
return $default(_that.id,_that.ticker,_that.displayName,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Underlying implements Underlying {
  const _Underlying({required this.id, required this.ticker, this.displayName, this.notes});
  factory _Underlying.fromJson(Map<String, dynamic> json) => _$UnderlyingFromJson(json);

@override final  String id;
@override final  String ticker;
@override final  String? displayName;
@override final  String? notes;

/// Create a copy of Underlying
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnderlyingCopyWith<_Underlying> get copyWith => __$UnderlyingCopyWithImpl<_Underlying>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UnderlyingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Underlying&&(identical(other.id, id) || other.id == id)&&(identical(other.ticker, ticker) || other.ticker == ticker)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ticker,displayName,notes);

@override
String toString() {
  return 'Underlying(id: $id, ticker: $ticker, displayName: $displayName, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$UnderlyingCopyWith<$Res> implements $UnderlyingCopyWith<$Res> {
  factory _$UnderlyingCopyWith(_Underlying value, $Res Function(_Underlying) _then) = __$UnderlyingCopyWithImpl;
@override @useResult
$Res call({
 String id, String ticker, String? displayName, String? notes
});




}
/// @nodoc
class __$UnderlyingCopyWithImpl<$Res>
    implements _$UnderlyingCopyWith<$Res> {
  __$UnderlyingCopyWithImpl(this._self, this._then);

  final _Underlying _self;
  final $Res Function(_Underlying) _then;

/// Create a copy of Underlying
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ticker = null,Object? displayName = freezed,Object? notes = freezed,}) {
  return _then(_Underlying(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ticker: null == ticker ? _self.ticker : ticker // ignore: cast_nullable_to_non_nullable
as String,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
