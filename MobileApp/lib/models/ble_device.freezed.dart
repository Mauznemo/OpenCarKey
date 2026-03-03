// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BleDevice {
  String get macAddress;
  bool get isConnected;

  /// Create a copy of BleDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BleDeviceCopyWith<BleDevice> get copyWith =>
      _$BleDeviceCopyWithImpl<BleDevice>(this as BleDevice, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BleDevice &&
            (identical(other.macAddress, macAddress) ||
                other.macAddress == macAddress) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, macAddress, isConnected);

  @override
  String toString() {
    return 'BleDevice(macAddress: $macAddress, isConnected: $isConnected)';
  }
}

/// @nodoc
abstract mixin class $BleDeviceCopyWith<$Res> {
  factory $BleDeviceCopyWith(BleDevice value, $Res Function(BleDevice) _then) =
      _$BleDeviceCopyWithImpl;
  @useResult
  $Res call({String macAddress, bool isConnected});
}

/// @nodoc
class _$BleDeviceCopyWithImpl<$Res> implements $BleDeviceCopyWith<$Res> {
  _$BleDeviceCopyWithImpl(this._self, this._then);

  final BleDevice _self;
  final $Res Function(BleDevice) _then;

  /// Create a copy of BleDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? macAddress = null,
    Object? isConnected = null,
  }) {
    return _then(_self.copyWith(
      macAddress: null == macAddress
          ? _self.macAddress
          : macAddress // ignore: cast_nullable_to_non_nullable
              as String,
      isConnected: null == isConnected
          ? _self.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [BleDevice].
extension BleDevicePatterns on BleDevice {
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
    TResult Function(_BleDevice value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BleDevice() when $default != null:
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
    TResult Function(_BleDevice value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BleDevice():
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
    TResult? Function(_BleDevice value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BleDevice() when $default != null:
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
    TResult Function(String macAddress, bool isConnected)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BleDevice() when $default != null:
        return $default(_that.macAddress, _that.isConnected);
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
    TResult Function(String macAddress, bool isConnected) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BleDevice():
        return $default(_that.macAddress, _that.isConnected);
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
    TResult? Function(String macAddress, bool isConnected)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BleDevice() when $default != null:
        return $default(_that.macAddress, _that.isConnected);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BleDevice implements BleDevice {
  const _BleDevice({required this.macAddress, this.isConnected = false});

  @override
  final String macAddress;
  @override
  @JsonKey()
  final bool isConnected;

  /// Create a copy of BleDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BleDeviceCopyWith<_BleDevice> get copyWith =>
      __$BleDeviceCopyWithImpl<_BleDevice>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BleDevice &&
            (identical(other.macAddress, macAddress) ||
                other.macAddress == macAddress) &&
            (identical(other.isConnected, isConnected) ||
                other.isConnected == isConnected));
  }

  @override
  int get hashCode => Object.hash(runtimeType, macAddress, isConnected);

  @override
  String toString() {
    return 'BleDevice(macAddress: $macAddress, isConnected: $isConnected)';
  }
}

/// @nodoc
abstract mixin class _$BleDeviceCopyWith<$Res>
    implements $BleDeviceCopyWith<$Res> {
  factory _$BleDeviceCopyWith(
          _BleDevice value, $Res Function(_BleDevice) _then) =
      __$BleDeviceCopyWithImpl;
  @override
  @useResult
  $Res call({String macAddress, bool isConnected});
}

/// @nodoc
class __$BleDeviceCopyWithImpl<$Res> implements _$BleDeviceCopyWith<$Res> {
  __$BleDeviceCopyWithImpl(this._self, this._then);

  final _BleDevice _self;
  final $Res Function(_BleDevice) _then;

  /// Create a copy of BleDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? macAddress = null,
    Object? isConnected = null,
  }) {
    return _then(_BleDevice(
      macAddress: null == macAddress
          ? _self.macAddress
          : macAddress // ignore: cast_nullable_to_non_nullable
              as String,
      isConnected: null == isConnected
          ? _self.isConnected
          : isConnected // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
