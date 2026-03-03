import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    @Default(true) bool proximityKey,
    @Default(false) bool ignoreProtocolMismatch,
    @Default(true) bool showMacAddress,
    @Default(true) bool vibrate,
    @Default(-200) double triggerStrength,
    @Default(4) double deadZone,
    @Default(1) double proximityCooldown,
    @Default(true) bool backgroundService,
  }) = _SettingsState;
}
