// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_preferences.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserPreferencesData {

/// "Total per contract" toggle (Feature Invariant 21): one global
/// preference applied uniformly at all four no-arbitrage-bound entry
/// points (screener credit, snapshot option mark, roll planner's
/// `newCredit`/`buybackDebit`, assignment covered-call credit) —
/// never a per-field or per-screen setting.
 bool get totalPerContractToggle;/// Pre-fills the delta-convention control on the *next* snapshot-entry
/// form only (Feature Invariant 5) — never rewrites a `Snapshot`
/// already written, since `deltaConvention` is stored per snapshot,
/// immutable after write.
 DeltaConvention get deltaConventionDefault;/// First-run explainer (brief-followup §C3) shows once, automatically,
/// then this flips permanently — re-opening it from Settings never
/// re-arms the automatic trigger.
 bool get firstRunExplainerShown;/// One-time IV-resolution note (Feature Invariant 24, Q9): a single
/// global, app-wide, not per-leg, dismissable banner flag.
 bool get ivResolutionNoticeDismissed;/// The 30-day export reminder (Feature Invariant 34): a single
/// lifetime flag, matching `firstRunExplainerShown`'s pattern — shown
/// once, ever, never a rolling per-30-days re-arm.
 bool get exportReminderDismissed;/// When the export was last run, or `null` if never. Read by the
/// Phase 20 reminder to decide whether 30+ days have elapsed since the
/// last export; writing it is that phase's job, not the repository's.
 DateTime? get lastExportAt;/// DTE milestones at which an expiration notification fires (Phase 21).
/// A Settings change here only pre-fills the *next* leg's schedule
/// (Feature Invariant 31) — it never reschedules an already-open leg's
/// already-scheduled notifications.
 List<int> get notificationMilestones;/// The user's wheel capital, in dollars, or `null` when they have not
/// set one (Pro Wave 1, D-6). Stored on disk as integer **cents** —
/// equity money, never ten-thousandths — and `null` is a real state
/// ("not set"), not zero: the concentration readout is simply absent
/// until a value exists. A value outside `(0, ∞)` is refused at entry.
@NullableDecimalJsonConverter() Decimal? get wheelCapital;/// The share of [wheelCapital] one position may occupy, as a
/// percentage in `(0, 100]` (Pro Wave 1, D-6). Dimensionless, so a
/// `double` like the Greeks — it feeds no gate. A value outside that
/// range is refused at entry; the default is the brief's 25%.
 double get concentrationLimitPct;
/// Create a copy of UserPreferencesData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserPreferencesDataCopyWith<UserPreferencesData> get copyWith => _$UserPreferencesDataCopyWithImpl<UserPreferencesData>(this as UserPreferencesData, _$identity);

  /// Serializes this UserPreferencesData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserPreferencesData&&(identical(other.totalPerContractToggle, totalPerContractToggle) || other.totalPerContractToggle == totalPerContractToggle)&&(identical(other.deltaConventionDefault, deltaConventionDefault) || other.deltaConventionDefault == deltaConventionDefault)&&(identical(other.firstRunExplainerShown, firstRunExplainerShown) || other.firstRunExplainerShown == firstRunExplainerShown)&&(identical(other.ivResolutionNoticeDismissed, ivResolutionNoticeDismissed) || other.ivResolutionNoticeDismissed == ivResolutionNoticeDismissed)&&(identical(other.exportReminderDismissed, exportReminderDismissed) || other.exportReminderDismissed == exportReminderDismissed)&&(identical(other.lastExportAt, lastExportAt) || other.lastExportAt == lastExportAt)&&const DeepCollectionEquality().equals(other.notificationMilestones, notificationMilestones)&&(identical(other.wheelCapital, wheelCapital) || other.wheelCapital == wheelCapital)&&(identical(other.concentrationLimitPct, concentrationLimitPct) || other.concentrationLimitPct == concentrationLimitPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalPerContractToggle,deltaConventionDefault,firstRunExplainerShown,ivResolutionNoticeDismissed,exportReminderDismissed,lastExportAt,const DeepCollectionEquality().hash(notificationMilestones),wheelCapital,concentrationLimitPct);

@override
String toString() {
  return 'UserPreferencesData(totalPerContractToggle: $totalPerContractToggle, deltaConventionDefault: $deltaConventionDefault, firstRunExplainerShown: $firstRunExplainerShown, ivResolutionNoticeDismissed: $ivResolutionNoticeDismissed, exportReminderDismissed: $exportReminderDismissed, lastExportAt: $lastExportAt, notificationMilestones: $notificationMilestones, wheelCapital: $wheelCapital, concentrationLimitPct: $concentrationLimitPct)';
}


}

/// @nodoc
abstract mixin class $UserPreferencesDataCopyWith<$Res>  {
  factory $UserPreferencesDataCopyWith(UserPreferencesData value, $Res Function(UserPreferencesData) _then) = _$UserPreferencesDataCopyWithImpl;
@useResult
$Res call({
 bool totalPerContractToggle, DeltaConvention deltaConventionDefault, bool firstRunExplainerShown, bool ivResolutionNoticeDismissed, bool exportReminderDismissed, DateTime? lastExportAt, List<int> notificationMilestones,@NullableDecimalJsonConverter() Decimal? wheelCapital, double concentrationLimitPct
});




}
/// @nodoc
class _$UserPreferencesDataCopyWithImpl<$Res>
    implements $UserPreferencesDataCopyWith<$Res> {
  _$UserPreferencesDataCopyWithImpl(this._self, this._then);

  final UserPreferencesData _self;
  final $Res Function(UserPreferencesData) _then;

/// Create a copy of UserPreferencesData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalPerContractToggle = null,Object? deltaConventionDefault = null,Object? firstRunExplainerShown = null,Object? ivResolutionNoticeDismissed = null,Object? exportReminderDismissed = null,Object? lastExportAt = freezed,Object? notificationMilestones = null,Object? wheelCapital = freezed,Object? concentrationLimitPct = null,}) {
  return _then(_self.copyWith(
totalPerContractToggle: null == totalPerContractToggle ? _self.totalPerContractToggle : totalPerContractToggle // ignore: cast_nullable_to_non_nullable
as bool,deltaConventionDefault: null == deltaConventionDefault ? _self.deltaConventionDefault : deltaConventionDefault // ignore: cast_nullable_to_non_nullable
as DeltaConvention,firstRunExplainerShown: null == firstRunExplainerShown ? _self.firstRunExplainerShown : firstRunExplainerShown // ignore: cast_nullable_to_non_nullable
as bool,ivResolutionNoticeDismissed: null == ivResolutionNoticeDismissed ? _self.ivResolutionNoticeDismissed : ivResolutionNoticeDismissed // ignore: cast_nullable_to_non_nullable
as bool,exportReminderDismissed: null == exportReminderDismissed ? _self.exportReminderDismissed : exportReminderDismissed // ignore: cast_nullable_to_non_nullable
as bool,lastExportAt: freezed == lastExportAt ? _self.lastExportAt : lastExportAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notificationMilestones: null == notificationMilestones ? _self.notificationMilestones : notificationMilestones // ignore: cast_nullable_to_non_nullable
as List<int>,wheelCapital: freezed == wheelCapital ? _self.wheelCapital : wheelCapital // ignore: cast_nullable_to_non_nullable
as Decimal?,concentrationLimitPct: null == concentrationLimitPct ? _self.concentrationLimitPct : concentrationLimitPct // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [UserPreferencesData].
extension UserPreferencesDataPatterns on UserPreferencesData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserPreferencesData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserPreferencesData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserPreferencesData value)  $default,){
final _that = this;
switch (_that) {
case _UserPreferencesData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserPreferencesData value)?  $default,){
final _that = this;
switch (_that) {
case _UserPreferencesData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool totalPerContractToggle,  DeltaConvention deltaConventionDefault,  bool firstRunExplainerShown,  bool ivResolutionNoticeDismissed,  bool exportReminderDismissed,  DateTime? lastExportAt,  List<int> notificationMilestones, @NullableDecimalJsonConverter()  Decimal? wheelCapital,  double concentrationLimitPct)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserPreferencesData() when $default != null:
return $default(_that.totalPerContractToggle,_that.deltaConventionDefault,_that.firstRunExplainerShown,_that.ivResolutionNoticeDismissed,_that.exportReminderDismissed,_that.lastExportAt,_that.notificationMilestones,_that.wheelCapital,_that.concentrationLimitPct);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool totalPerContractToggle,  DeltaConvention deltaConventionDefault,  bool firstRunExplainerShown,  bool ivResolutionNoticeDismissed,  bool exportReminderDismissed,  DateTime? lastExportAt,  List<int> notificationMilestones, @NullableDecimalJsonConverter()  Decimal? wheelCapital,  double concentrationLimitPct)  $default,) {final _that = this;
switch (_that) {
case _UserPreferencesData():
return $default(_that.totalPerContractToggle,_that.deltaConventionDefault,_that.firstRunExplainerShown,_that.ivResolutionNoticeDismissed,_that.exportReminderDismissed,_that.lastExportAt,_that.notificationMilestones,_that.wheelCapital,_that.concentrationLimitPct);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool totalPerContractToggle,  DeltaConvention deltaConventionDefault,  bool firstRunExplainerShown,  bool ivResolutionNoticeDismissed,  bool exportReminderDismissed,  DateTime? lastExportAt,  List<int> notificationMilestones, @NullableDecimalJsonConverter()  Decimal? wheelCapital,  double concentrationLimitPct)?  $default,) {final _that = this;
switch (_that) {
case _UserPreferencesData() when $default != null:
return $default(_that.totalPerContractToggle,_that.deltaConventionDefault,_that.firstRunExplainerShown,_that.ivResolutionNoticeDismissed,_that.exportReminderDismissed,_that.lastExportAt,_that.notificationMilestones,_that.wheelCapital,_that.concentrationLimitPct);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserPreferencesData implements UserPreferencesData {
  const _UserPreferencesData({this.totalPerContractToggle = false, this.deltaConventionDefault = DeltaConvention.position, this.firstRunExplainerShown = false, this.ivResolutionNoticeDismissed = false, this.exportReminderDismissed = false, this.lastExportAt, final  List<int> notificationMilestones = const [21, 7, 0], @NullableDecimalJsonConverter() this.wheelCapital, this.concentrationLimitPct = 25.0}): _notificationMilestones = notificationMilestones;
  factory _UserPreferencesData.fromJson(Map<String, dynamic> json) => _$UserPreferencesDataFromJson(json);

/// "Total per contract" toggle (Feature Invariant 21): one global
/// preference applied uniformly at all four no-arbitrage-bound entry
/// points (screener credit, snapshot option mark, roll planner's
/// `newCredit`/`buybackDebit`, assignment covered-call credit) —
/// never a per-field or per-screen setting.
@override@JsonKey() final  bool totalPerContractToggle;
/// Pre-fills the delta-convention control on the *next* snapshot-entry
/// form only (Feature Invariant 5) — never rewrites a `Snapshot`
/// already written, since `deltaConvention` is stored per snapshot,
/// immutable after write.
@override@JsonKey() final  DeltaConvention deltaConventionDefault;
/// First-run explainer (brief-followup §C3) shows once, automatically,
/// then this flips permanently — re-opening it from Settings never
/// re-arms the automatic trigger.
@override@JsonKey() final  bool firstRunExplainerShown;
/// One-time IV-resolution note (Feature Invariant 24, Q9): a single
/// global, app-wide, not per-leg, dismissable banner flag.
@override@JsonKey() final  bool ivResolutionNoticeDismissed;
/// The 30-day export reminder (Feature Invariant 34): a single
/// lifetime flag, matching `firstRunExplainerShown`'s pattern — shown
/// once, ever, never a rolling per-30-days re-arm.
@override@JsonKey() final  bool exportReminderDismissed;
/// When the export was last run, or `null` if never. Read by the
/// Phase 20 reminder to decide whether 30+ days have elapsed since the
/// last export; writing it is that phase's job, not the repository's.
@override final  DateTime? lastExportAt;
/// DTE milestones at which an expiration notification fires (Phase 21).
/// A Settings change here only pre-fills the *next* leg's schedule
/// (Feature Invariant 31) — it never reschedules an already-open leg's
/// already-scheduled notifications.
 final  List<int> _notificationMilestones;
/// DTE milestones at which an expiration notification fires (Phase 21).
/// A Settings change here only pre-fills the *next* leg's schedule
/// (Feature Invariant 31) — it never reschedules an already-open leg's
/// already-scheduled notifications.
@override@JsonKey() List<int> get notificationMilestones {
  if (_notificationMilestones is EqualUnmodifiableListView) return _notificationMilestones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notificationMilestones);
}

/// The user's wheel capital, in dollars, or `null` when they have not
/// set one (Pro Wave 1, D-6). Stored on disk as integer **cents** —
/// equity money, never ten-thousandths — and `null` is a real state
/// ("not set"), not zero: the concentration readout is simply absent
/// until a value exists. A value outside `(0, ∞)` is refused at entry.
@override@NullableDecimalJsonConverter() final  Decimal? wheelCapital;
/// The share of [wheelCapital] one position may occupy, as a
/// percentage in `(0, 100]` (Pro Wave 1, D-6). Dimensionless, so a
/// `double` like the Greeks — it feeds no gate. A value outside that
/// range is refused at entry; the default is the brief's 25%.
@override@JsonKey() final  double concentrationLimitPct;

/// Create a copy of UserPreferencesData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserPreferencesDataCopyWith<_UserPreferencesData> get copyWith => __$UserPreferencesDataCopyWithImpl<_UserPreferencesData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserPreferencesDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserPreferencesData&&(identical(other.totalPerContractToggle, totalPerContractToggle) || other.totalPerContractToggle == totalPerContractToggle)&&(identical(other.deltaConventionDefault, deltaConventionDefault) || other.deltaConventionDefault == deltaConventionDefault)&&(identical(other.firstRunExplainerShown, firstRunExplainerShown) || other.firstRunExplainerShown == firstRunExplainerShown)&&(identical(other.ivResolutionNoticeDismissed, ivResolutionNoticeDismissed) || other.ivResolutionNoticeDismissed == ivResolutionNoticeDismissed)&&(identical(other.exportReminderDismissed, exportReminderDismissed) || other.exportReminderDismissed == exportReminderDismissed)&&(identical(other.lastExportAt, lastExportAt) || other.lastExportAt == lastExportAt)&&const DeepCollectionEquality().equals(other._notificationMilestones, _notificationMilestones)&&(identical(other.wheelCapital, wheelCapital) || other.wheelCapital == wheelCapital)&&(identical(other.concentrationLimitPct, concentrationLimitPct) || other.concentrationLimitPct == concentrationLimitPct));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totalPerContractToggle,deltaConventionDefault,firstRunExplainerShown,ivResolutionNoticeDismissed,exportReminderDismissed,lastExportAt,const DeepCollectionEquality().hash(_notificationMilestones),wheelCapital,concentrationLimitPct);

@override
String toString() {
  return 'UserPreferencesData(totalPerContractToggle: $totalPerContractToggle, deltaConventionDefault: $deltaConventionDefault, firstRunExplainerShown: $firstRunExplainerShown, ivResolutionNoticeDismissed: $ivResolutionNoticeDismissed, exportReminderDismissed: $exportReminderDismissed, lastExportAt: $lastExportAt, notificationMilestones: $notificationMilestones, wheelCapital: $wheelCapital, concentrationLimitPct: $concentrationLimitPct)';
}


}

/// @nodoc
abstract mixin class _$UserPreferencesDataCopyWith<$Res> implements $UserPreferencesDataCopyWith<$Res> {
  factory _$UserPreferencesDataCopyWith(_UserPreferencesData value, $Res Function(_UserPreferencesData) _then) = __$UserPreferencesDataCopyWithImpl;
@override @useResult
$Res call({
 bool totalPerContractToggle, DeltaConvention deltaConventionDefault, bool firstRunExplainerShown, bool ivResolutionNoticeDismissed, bool exportReminderDismissed, DateTime? lastExportAt, List<int> notificationMilestones,@NullableDecimalJsonConverter() Decimal? wheelCapital, double concentrationLimitPct
});




}
/// @nodoc
class __$UserPreferencesDataCopyWithImpl<$Res>
    implements _$UserPreferencesDataCopyWith<$Res> {
  __$UserPreferencesDataCopyWithImpl(this._self, this._then);

  final _UserPreferencesData _self;
  final $Res Function(_UserPreferencesData) _then;

/// Create a copy of UserPreferencesData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalPerContractToggle = null,Object? deltaConventionDefault = null,Object? firstRunExplainerShown = null,Object? ivResolutionNoticeDismissed = null,Object? exportReminderDismissed = null,Object? lastExportAt = freezed,Object? notificationMilestones = null,Object? wheelCapital = freezed,Object? concentrationLimitPct = null,}) {
  return _then(_UserPreferencesData(
totalPerContractToggle: null == totalPerContractToggle ? _self.totalPerContractToggle : totalPerContractToggle // ignore: cast_nullable_to_non_nullable
as bool,deltaConventionDefault: null == deltaConventionDefault ? _self.deltaConventionDefault : deltaConventionDefault // ignore: cast_nullable_to_non_nullable
as DeltaConvention,firstRunExplainerShown: null == firstRunExplainerShown ? _self.firstRunExplainerShown : firstRunExplainerShown // ignore: cast_nullable_to_non_nullable
as bool,ivResolutionNoticeDismissed: null == ivResolutionNoticeDismissed ? _self.ivResolutionNoticeDismissed : ivResolutionNoticeDismissed // ignore: cast_nullable_to_non_nullable
as bool,exportReminderDismissed: null == exportReminderDismissed ? _self.exportReminderDismissed : exportReminderDismissed // ignore: cast_nullable_to_non_nullable
as bool,lastExportAt: freezed == lastExportAt ? _self.lastExportAt : lastExportAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notificationMilestones: null == notificationMilestones ? _self._notificationMilestones : notificationMilestones // ignore: cast_nullable_to_non_nullable
as List<int>,wheelCapital: freezed == wheelCapital ? _self.wheelCapital : wheelCapital // ignore: cast_nullable_to_non_nullable
as Decimal?,concentrationLimitPct: null == concentrationLimitPct ? _self.concentrationLimitPct : concentrationLimitPct // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
