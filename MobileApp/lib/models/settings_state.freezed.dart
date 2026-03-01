// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SettingsState {
  bool get proximityKey;
  bool get ignoreProtocolMismatch;
  bool get showMacAddress;
  bool get vibrate;
  double get triggerStrength;
  double get deadZone;
  double get proximityCooldown;
  bool get backgroundService;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsStateCopyWith<SettingsState> get copyWith =>
      _$SettingsStateCopyWithImpl<SettingsState>(
          this as SettingsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsState &&
            (identical(other.proximityKey, proximityKey) ||
                other.proximityKey == proximityKey) &&
            (identical(other.ignoreProtocolMismatch, ignoreProtocolMismatch) ||
                other.ignoreProtocolMismatch == ignoreProtocolMismatch) &&
            (identical(other.showMacAddress, showMacAddress) ||
                other.showMacAddress == showMacAddress) &&
            (identical(other.vibrate, vibrate) || other.vibrate == vibrate) &&
            (identical(other.triggerStrength, triggerStrength) ||
                other.triggerStrength == triggerStrength) &&
            (identical(other.deadZone, deadZone) ||
                other.deadZone == deadZone) &&
            (identical(other.proximityCooldown, proximityCooldown) ||
                other.proximityCooldown == proximityCooldown) &&
            (identical(other.backgroundService, backgroundService) ||
                other.backgroundService == backgroundService));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      proximityKey,
      ignoreProtocolMismatch,
      showMacAddress,
      vibrate,
      triggerStrength,
      deadZone,
      proximityCooldown,
      backgroundService);

  @override
  String toString() {
    return 'SettingsState(proximityKey: $proximityKey, ignoreProtocolMismatch: $ignoreProtocolMismatch, showMacAddress: $showMacAddress, vibrate: $vibrate, triggerStrength: $triggerStrength, deadZone: $deadZone, proximityCooldown: $proximityCooldown, backgroundService: $backgroundService)';
  }
}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res> {
  factory $SettingsStateCopyWith(
          SettingsState value, $Res Function(SettingsState) _then) =
      _$SettingsStateCopyWithImpl;
  @useResult
  $Res call(
      {bool proximityKey,
      bool ignoreProtocolMismatch,
      bool showMacAddress,
      bool vibrate,
      double triggerStrength,
      double deadZone,
      double proximityCooldown,
      bool backgroundService});
}

/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? proximityKey = null,
    Object? ignoreProtocolMismatch = null,
    Object? showMacAddress = null,
    Object? vibrate = null,
    Object? triggerStrength = null,
    Object? deadZone = null,
    Object? proximityCooldown = null,
    Object? backgroundService = null,
  }) {
    return _then(_self.copyWith(
      proximityKey: null == proximityKey
          ? _self.proximityKey
          : proximityKey // ignore: cast_nullable_to_non_nullable
              as bool,
      ignoreProtocolMismatch: null == ignoreProtocolMismatch
          ? _self.ignoreProtocolMismatch
          : ignoreProtocolMismatch // ignore: cast_nullable_to_non_nullable
              as bool,
      showMacAddress: null == showMacAddress
          ? _self.showMacAddress
          : showMacAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      vibrate: null == vibrate
          ? _self.vibrate
          : vibrate // ignore: cast_nullable_to_non_nullable
              as bool,
      triggerStrength: null == triggerStrength
          ? _self.triggerStrength
          : triggerStrength // ignore: cast_nullable_to_non_nullable
              as double,
      deadZone: null == deadZone
          ? _self.deadZone
          : deadZone // ignore: cast_nullable_to_non_nullable
              as double,
      proximityCooldown: null == proximityCooldown
          ? _self.proximityCooldown
          : proximityCooldown // ignore: cast_nullable_to_non_nullable
              as double,
      backgroundService: null == backgroundService
          ? _self.backgroundService
          : backgroundService // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [SettingsState].
extension SettingsStatePatterns on SettingsState {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SettingsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SettingsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SettingsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            bool proximityKey,
            bool ignoreProtocolMismatch,
            bool showMacAddress,
            bool vibrate,
            double triggerStrength,
            double deadZone,
            double proximityCooldown,
            bool backgroundService)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(
            _that.proximityKey,
            _that.ignoreProtocolMismatch,
            _that.showMacAddress,
            _that.vibrate,
            _that.triggerStrength,
            _that.deadZone,
            _that.proximityCooldown,
            _that.backgroundService);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            bool proximityKey,
            bool ignoreProtocolMismatch,
            bool showMacAddress,
            bool vibrate,
            double triggerStrength,
            double deadZone,
            double proximityCooldown,
            bool backgroundService)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState():
        return $default(
            _that.proximityKey,
            _that.ignoreProtocolMismatch,
            _that.showMacAddress,
            _that.vibrate,
            _that.triggerStrength,
            _that.deadZone,
            _that.proximityCooldown,
            _that.backgroundService);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            bool proximityKey,
            bool ignoreProtocolMismatch,
            bool showMacAddress,
            bool vibrate,
            double triggerStrength,
            double deadZone,
            double proximityCooldown,
            bool backgroundService)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(
            _that.proximityKey,
            _that.ignoreProtocolMismatch,
            _that.showMacAddress,
            _that.vibrate,
            _that.triggerStrength,
            _that.deadZone,
            _that.proximityCooldown,
            _that.backgroundService);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SettingsState implements SettingsState {
  const _SettingsState(
      {this.proximityKey = true,
      this.ignoreProtocolMismatch = false,
      this.showMacAddress = true,
      this.vibrate = true,
      this.triggerStrength = -200,
      this.deadZone = 4,
      this.proximityCooldown = 1,
      this.backgroundService = true});

  @override
  @JsonKey()
  final bool proximityKey;
  @override
  @JsonKey()
  final bool ignoreProtocolMismatch;
  @override
  @JsonKey()
  final bool showMacAddress;
  @override
  @JsonKey()
  final bool vibrate;
  @override
  @JsonKey()
  final double triggerStrength;
  @override
  @JsonKey()
  final double deadZone;
  @override
  @JsonKey()
  final double proximityCooldown;
  @override
  @JsonKey()
  final bool backgroundService;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SettingsStateCopyWith<_SettingsState> get copyWith =>
      __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SettingsState &&
            (identical(other.proximityKey, proximityKey) ||
                other.proximityKey == proximityKey) &&
            (identical(other.ignoreProtocolMismatch, ignoreProtocolMismatch) ||
                other.ignoreProtocolMismatch == ignoreProtocolMismatch) &&
            (identical(other.showMacAddress, showMacAddress) ||
                other.showMacAddress == showMacAddress) &&
            (identical(other.vibrate, vibrate) || other.vibrate == vibrate) &&
            (identical(other.triggerStrength, triggerStrength) ||
                other.triggerStrength == triggerStrength) &&
            (identical(other.deadZone, deadZone) ||
                other.deadZone == deadZone) &&
            (identical(other.proximityCooldown, proximityCooldown) ||
                other.proximityCooldown == proximityCooldown) &&
            (identical(other.backgroundService, backgroundService) ||
                other.backgroundService == backgroundService));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      proximityKey,
      ignoreProtocolMismatch,
      showMacAddress,
      vibrate,
      triggerStrength,
      deadZone,
      proximityCooldown,
      backgroundService);

  @override
  String toString() {
    return 'SettingsState(proximityKey: $proximityKey, ignoreProtocolMismatch: $ignoreProtocolMismatch, showMacAddress: $showMacAddress, vibrate: $vibrate, triggerStrength: $triggerStrength, deadZone: $deadZone, proximityCooldown: $proximityCooldown, backgroundService: $backgroundService)';
  }
}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res>
    implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(
          _SettingsState value, $Res Function(_SettingsState) _then) =
      __$SettingsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool proximityKey,
      bool ignoreProtocolMismatch,
      bool showMacAddress,
      bool vibrate,
      double triggerStrength,
      double deadZone,
      double proximityCooldown,
      bool backgroundService});
}

/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? proximityKey = null,
    Object? ignoreProtocolMismatch = null,
    Object? showMacAddress = null,
    Object? vibrate = null,
    Object? triggerStrength = null,
    Object? deadZone = null,
    Object? proximityCooldown = null,
    Object? backgroundService = null,
  }) {
    return _then(_SettingsState(
      proximityKey: null == proximityKey
          ? _self.proximityKey
          : proximityKey // ignore: cast_nullable_to_non_nullable
              as bool,
      ignoreProtocolMismatch: null == ignoreProtocolMismatch
          ? _self.ignoreProtocolMismatch
          : ignoreProtocolMismatch // ignore: cast_nullable_to_non_nullable
              as bool,
      showMacAddress: null == showMacAddress
          ? _self.showMacAddress
          : showMacAddress // ignore: cast_nullable_to_non_nullable
              as bool,
      vibrate: null == vibrate
          ? _self.vibrate
          : vibrate // ignore: cast_nullable_to_non_nullable
              as bool,
      triggerStrength: null == triggerStrength
          ? _self.triggerStrength
          : triggerStrength // ignore: cast_nullable_to_non_nullable
              as double,
      deadZone: null == deadZone
          ? _self.deadZone
          : deadZone // ignore: cast_nullable_to_non_nullable
              as double,
      proximityCooldown: null == proximityCooldown
          ? _self.proximityCooldown
          : proximityCooldown // ignore: cast_nullable_to_non_nullable
              as double,
      backgroundService: null == backgroundService
          ? _self.backgroundService
          : backgroundService // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
