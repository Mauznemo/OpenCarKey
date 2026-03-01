// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vehicles_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VehiclesState {
  List<Vehicle> get vehicles;
  List<String> get unauthenticatedVehicles;
  List<String> get outdatedVehicles;

  /// Create a copy of VehiclesState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $VehiclesStateCopyWith<VehiclesState> get copyWith =>
      _$VehiclesStateCopyWithImpl<VehiclesState>(
          this as VehiclesState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is VehiclesState &&
            const DeepCollectionEquality().equals(other.vehicles, vehicles) &&
            const DeepCollectionEquality().equals(
                other.unauthenticatedVehicles, unauthenticatedVehicles) &&
            const DeepCollectionEquality()
                .equals(other.outdatedVehicles, outdatedVehicles));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(vehicles),
      const DeepCollectionEquality().hash(unauthenticatedVehicles),
      const DeepCollectionEquality().hash(outdatedVehicles));

  @override
  String toString() {
    return 'VehiclesState(vehicles: $vehicles, unauthenticatedVehicles: $unauthenticatedVehicles, outdatedVehicles: $outdatedVehicles)';
  }
}

/// @nodoc
abstract mixin class $VehiclesStateCopyWith<$Res> {
  factory $VehiclesStateCopyWith(
          VehiclesState value, $Res Function(VehiclesState) _then) =
      _$VehiclesStateCopyWithImpl;
  @useResult
  $Res call(
      {List<Vehicle> vehicles,
      List<String> unauthenticatedVehicles,
      List<String> outdatedVehicles});
}

/// @nodoc
class _$VehiclesStateCopyWithImpl<$Res>
    implements $VehiclesStateCopyWith<$Res> {
  _$VehiclesStateCopyWithImpl(this._self, this._then);

  final VehiclesState _self;
  final $Res Function(VehiclesState) _then;

  /// Create a copy of VehiclesState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vehicles = null,
    Object? unauthenticatedVehicles = null,
    Object? outdatedVehicles = null,
  }) {
    return _then(_self.copyWith(
      vehicles: null == vehicles
          ? _self.vehicles
          : vehicles // ignore: cast_nullable_to_non_nullable
              as List<Vehicle>,
      unauthenticatedVehicles: null == unauthenticatedVehicles
          ? _self.unauthenticatedVehicles
          : unauthenticatedVehicles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      outdatedVehicles: null == outdatedVehicles
          ? _self.outdatedVehicles
          : outdatedVehicles // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [VehiclesState].
extension VehiclesStatePatterns on VehiclesState {
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
    TResult Function(_VehiclesState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VehiclesState() when $default != null:
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
    TResult Function(_VehiclesState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VehiclesState():
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
    TResult? Function(_VehiclesState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VehiclesState() when $default != null:
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
            List<Vehicle> vehicles,
            List<String> unauthenticatedVehicles,
            List<String> outdatedVehicles)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _VehiclesState() when $default != null:
        return $default(_that.vehicles, _that.unauthenticatedVehicles,
            _that.outdatedVehicles);
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
    TResult Function(List<Vehicle> vehicles,
            List<String> unauthenticatedVehicles, List<String> outdatedVehicles)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VehiclesState():
        return $default(_that.vehicles, _that.unauthenticatedVehicles,
            _that.outdatedVehicles);
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
            List<Vehicle> vehicles,
            List<String> unauthenticatedVehicles,
            List<String> outdatedVehicles)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _VehiclesState() when $default != null:
        return $default(_that.vehicles, _that.unauthenticatedVehicles,
            _that.outdatedVehicles);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _VehiclesState extends VehiclesState {
  const _VehiclesState(
      {final List<Vehicle> vehicles = const [],
      final List<String> unauthenticatedVehicles = const [],
      final List<String> outdatedVehicles = const []})
      : _vehicles = vehicles,
        _unauthenticatedVehicles = unauthenticatedVehicles,
        _outdatedVehicles = outdatedVehicles,
        super._();

  final List<Vehicle> _vehicles;
  @override
  @JsonKey()
  List<Vehicle> get vehicles {
    if (_vehicles is EqualUnmodifiableListView) return _vehicles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_vehicles);
  }

  final List<String> _unauthenticatedVehicles;
  @override
  @JsonKey()
  List<String> get unauthenticatedVehicles {
    if (_unauthenticatedVehicles is EqualUnmodifiableListView)
      return _unauthenticatedVehicles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_unauthenticatedVehicles);
  }

  final List<String> _outdatedVehicles;
  @override
  @JsonKey()
  List<String> get outdatedVehicles {
    if (_outdatedVehicles is EqualUnmodifiableListView)
      return _outdatedVehicles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_outdatedVehicles);
  }

  /// Create a copy of VehiclesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$VehiclesStateCopyWith<_VehiclesState> get copyWith =>
      __$VehiclesStateCopyWithImpl<_VehiclesState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _VehiclesState &&
            const DeepCollectionEquality().equals(other._vehicles, _vehicles) &&
            const DeepCollectionEquality().equals(
                other._unauthenticatedVehicles, _unauthenticatedVehicles) &&
            const DeepCollectionEquality()
                .equals(other._outdatedVehicles, _outdatedVehicles));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_vehicles),
      const DeepCollectionEquality().hash(_unauthenticatedVehicles),
      const DeepCollectionEquality().hash(_outdatedVehicles));

  @override
  String toString() {
    return 'VehiclesState(vehicles: $vehicles, unauthenticatedVehicles: $unauthenticatedVehicles, outdatedVehicles: $outdatedVehicles)';
  }
}

/// @nodoc
abstract mixin class _$VehiclesStateCopyWith<$Res>
    implements $VehiclesStateCopyWith<$Res> {
  factory _$VehiclesStateCopyWith(
          _VehiclesState value, $Res Function(_VehiclesState) _then) =
      __$VehiclesStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<Vehicle> vehicles,
      List<String> unauthenticatedVehicles,
      List<String> outdatedVehicles});
}

/// @nodoc
class __$VehiclesStateCopyWithImpl<$Res>
    implements _$VehiclesStateCopyWith<$Res> {
  __$VehiclesStateCopyWithImpl(this._self, this._then);

  final _VehiclesState _self;
  final $Res Function(_VehiclesState) _then;

  /// Create a copy of VehiclesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? vehicles = null,
    Object? unauthenticatedVehicles = null,
    Object? outdatedVehicles = null,
  }) {
    return _then(_VehiclesState(
      vehicles: null == vehicles
          ? _self._vehicles
          : vehicles // ignore: cast_nullable_to_non_nullable
              as List<Vehicle>,
      unauthenticatedVehicles: null == unauthenticatedVehicles
          ? _self._unauthenticatedVehicles
          : unauthenticatedVehicles // ignore: cast_nullable_to_non_nullable
              as List<String>,
      outdatedVehicles: null == outdatedVehicles
          ? _self._outdatedVehicles
          : outdatedVehicles // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
