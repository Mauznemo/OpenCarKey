// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vehicle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Vehicle {
  BleDevice get device;
  VehicleData get data;
  bool get doorsLocked;
  bool get trunkLocked;
  bool get engineOn;

  /// Create a copy of Vehicle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VehicleCopyWith<Vehicle> get copyWith =>
      _$VehicleCopyWithImpl<Vehicle>(this as Vehicle, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Vehicle &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.doorsLocked, doorsLocked) ||
                other.doorsLocked == doorsLocked) &&
            (identical(other.trunkLocked, trunkLocked) ||
                other.trunkLocked == trunkLocked) &&
            (identical(other.engineOn, engineOn) ||
                other.engineOn == engineOn));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, device, data, doorsLocked, trunkLocked, engineOn);

  @override
  String toString() {
    return 'Vehicle(device: $device, data: $data, doorsLocked: $doorsLocked, trunkLocked: $trunkLocked, engineOn: $engineOn)';
  }
}

/// @nodoc
abstract mixin class $VehicleCopyWith<$Res> {
  factory $VehicleCopyWith(Vehicle value, $Res Function(Vehicle) _then) =
      _$VehicleCopyWithImpl;
  @useResult
  $Res call(
      {BleDevice device,
      VehicleData data,
      bool doorsLocked,
      bool trunkLocked,
      bool engineOn});

  $BleDeviceCopyWith<$Res> get device;
}

/// @nodoc
class _$VehicleCopyWithImpl<$Res> implements $VehicleCopyWith<$Res> {
  _$VehicleCopyWithImpl(this._self, this._then);

  final Vehicle _self;
  final $Res Function(Vehicle) _then;

  /// Create a copy of Vehicle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? device = null,
    Object? data = null,
    Object? doorsLocked = null,
    Object? trunkLocked = null,
    Object? engineOn = null,
  }) {
    return _then(_self.copyWith(
      device: null == device
          ? _self.device
          : device // ignore: cast_nullable_to_non_nullable
              as BleDevice,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as VehicleData,
      doorsLocked: null == doorsLocked
          ? _self.doorsLocked
          : doorsLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      trunkLocked: null == trunkLocked
          ? _self.trunkLocked
          : trunkLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      engineOn: null == engineOn
          ? _self.engineOn
          : engineOn // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of Vehicle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BleDeviceCopyWith<$Res> get device {
    return $BleDeviceCopyWith<$Res>(_self.device, (value) {
      return _then(_self.copyWith(device: value));
    });
  }
}

/// Adds pattern-matching-related methods to [Vehicle].
extension VehiclePatterns on Vehicle {
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
    TResult Function(_Vehicle value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Vehicle() when $default != null:
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
    TResult Function(_Vehicle value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vehicle():
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
    TResult? Function(_Vehicle value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vehicle() when $default != null:
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
    TResult Function(BleDevice device, VehicleData data, bool doorsLocked,
            bool trunkLocked, bool engineOn)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Vehicle() when $default != null:
        return $default(_that.device, _that.data, _that.doorsLocked,
            _that.trunkLocked, _that.engineOn);
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
    TResult Function(BleDevice device, VehicleData data, bool doorsLocked,
            bool trunkLocked, bool engineOn)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vehicle():
        return $default(_that.device, _that.data, _that.doorsLocked,
            _that.trunkLocked, _that.engineOn);
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
    TResult? Function(BleDevice device, VehicleData data, bool doorsLocked,
            bool trunkLocked, bool engineOn)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Vehicle() when $default != null:
        return $default(_that.device, _that.data, _that.doorsLocked,
            _that.trunkLocked, _that.engineOn);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Vehicle implements Vehicle {
  const _Vehicle(
      {required this.device,
      required this.data,
      this.doorsLocked = true,
      this.trunkLocked = true,
      this.engineOn = false});

  @override
  final BleDevice device;
  @override
  final VehicleData data;
  @override
  @JsonKey()
  final bool doorsLocked;
  @override
  @JsonKey()
  final bool trunkLocked;
  @override
  @JsonKey()
  final bool engineOn;

  /// Create a copy of Vehicle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VehicleCopyWith<_Vehicle> get copyWith =>
      __$VehicleCopyWithImpl<_Vehicle>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Vehicle &&
            (identical(other.device, device) || other.device == device) &&
            (identical(other.data, data) || other.data == data) &&
            (identical(other.doorsLocked, doorsLocked) ||
                other.doorsLocked == doorsLocked) &&
            (identical(other.trunkLocked, trunkLocked) ||
                other.trunkLocked == trunkLocked) &&
            (identical(other.engineOn, engineOn) ||
                other.engineOn == engineOn));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, device, data, doorsLocked, trunkLocked, engineOn);

  @override
  String toString() {
    return 'Vehicle(device: $device, data: $data, doorsLocked: $doorsLocked, trunkLocked: $trunkLocked, engineOn: $engineOn)';
  }
}

/// @nodoc
abstract mixin class _$VehicleCopyWith<$Res> implements $VehicleCopyWith<$Res> {
  factory _$VehicleCopyWith(_Vehicle value, $Res Function(_Vehicle) _then) =
      __$VehicleCopyWithImpl;
  @override
  @useResult
  $Res call(
      {BleDevice device,
      VehicleData data,
      bool doorsLocked,
      bool trunkLocked,
      bool engineOn});

  @override
  $BleDeviceCopyWith<$Res> get device;
}

/// @nodoc
class __$VehicleCopyWithImpl<$Res> implements _$VehicleCopyWith<$Res> {
  __$VehicleCopyWithImpl(this._self, this._then);

  final _Vehicle _self;
  final $Res Function(_Vehicle) _then;

  /// Create a copy of Vehicle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? device = null,
    Object? data = null,
    Object? doorsLocked = null,
    Object? trunkLocked = null,
    Object? engineOn = null,
  }) {
    return _then(_Vehicle(
      device: null == device
          ? _self.device
          : device // ignore: cast_nullable_to_non_nullable
              as BleDevice,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as VehicleData,
      doorsLocked: null == doorsLocked
          ? _self.doorsLocked
          : doorsLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      trunkLocked: null == trunkLocked
          ? _self.trunkLocked
          : trunkLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      engineOn: null == engineOn
          ? _self.engineOn
          : engineOn // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of Vehicle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BleDeviceCopyWith<$Res> get device {
    return $BleDeviceCopyWith<$Res>(_self.device, (value) {
      return _then(_self.copyWith(device: value));
    });
  }
}

// dart format on
