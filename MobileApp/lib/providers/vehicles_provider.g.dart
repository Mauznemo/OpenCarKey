// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VehiclesNotifier)
final vehiclesProvider = VehiclesNotifierProvider._();

final class VehiclesNotifierProvider
    extends $NotifierProvider<VehiclesNotifier, VehiclesState> {
  VehiclesNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'vehiclesProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$vehiclesNotifierHash();

  @$internal
  @override
  VehiclesNotifier create() => VehiclesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VehiclesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VehiclesState>(value),
    );
  }
}

String _$vehiclesNotifierHash() => r'5b7a8ae5272e12247aaa762c974da436bbff161b';

abstract class _$VehiclesNotifier extends $Notifier<VehiclesState> {
  VehiclesState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VehiclesState, VehiclesState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<VehiclesState, VehiclesState>,
        VehiclesState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
